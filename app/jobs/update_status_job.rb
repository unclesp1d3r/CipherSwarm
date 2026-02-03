# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# UpdateStatusJob is responsible for maintaining the status of agents and tasks in the system.
# It performs the following actions:
# - Checks the online status of agents that have been offline for more than a configurable amount of time.
# - Removes old status for tasks that are in a finished state.
# - Removes running status for incomplete tasks.
# - Abandons tasks that have been running for more than a configurable amount of time without activity.
#
# The job is executed with a high priority queue.
#
# Methods:
# - perform(*_args): Executes the status update operations within a database connection pool.
#   Ensures that active connections are cleared and closed after execution.
class UpdateStatusJob < ApplicationJob
  queue_as :high

  # Performs the following tasks:
  # 1. Checks the online status of agents that have been offline for more than a configurable amount of time.
  # 2. Removes old status for tasks in a finished state.
  # 3. Removes running status for incomplete tasks.
  # 4. Abandons tasks that have been running for more than a configurable amount of time without activity.
  # 5. Rebalances task assignments for high-priority campaigns.
  #
  ##
  # Executes periodic status maintenance tasks (agent heartbeats, task status cleanup, task abandonment, and assignment rebalancing)
  #
  # Runs the sequence of status-update operations: check agents' online status, remove status records for finished and incomplete tasks, abandon inactive running tasks, and rebalance task assignments for high-priority campaigns. Ensures the ActiveRecord connection pool is cleared of active connections after execution to avoid connection leaks.
  def perform(*_args)
    ActiveRecord::Base.connection_pool.with_connection do
      check_agents_online_status
      remove_finished_tasks_status
      remove_incomplete_tasks_status
      abandon_inactive_tasks
      rebalance_task_assignments
    end
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  private

  def abandon_inactive_tasks
    Task.with_state(:running).inactive_for(ApplicationConfig.task_considered_abandoned_age).each { |task| task.abandon }
  end

  ##
  # Checks agents that have been inactive longer than the configured offline threshold and invokes `check_online` on each candidate.
  # Uses ApplicationConfig.agent_considered_offline_time to determine the inactivity threshold.
  def check_agents_online_status
    offline_candidates = Agent.without_state(:offline).inactive_for(ApplicationConfig.agent_considered_offline_time)

    if offline_candidates.any?
      Rails.logger.info(
        "[AgentLifecycle] Checking #{offline_candidates.count} agents for heartbeat timeout - " \
        "Threshold: #{ApplicationConfig.agent_considered_offline_time}"
      )
    end

    offline_candidates.each(&:check_online)
  end

  ##
  # Removes all hashcat_status records associated with tasks that are in the finished state.
  def remove_finished_tasks_status
    # PERFORMANCE: Use batch deletion with a single SQL query instead of loading
    # all finished tasks into memory and deleting statuses one by one.
    # This changes from O(n) DELETE queries to a single DELETE with subquery.
    deleted_count = HashcatStatus.where(task_id: Task.finished.select(:id)).delete_all
    Rails.logger.info("[UpdateStatusJob] Removed #{deleted_count} hashcat_statuses for finished tasks") if deleted_count.positive?
  end

  ##
  # Removes outdated status entries for tasks that are currently in the incomplete state.
  # For each incomplete task, purges any stale or expired status data associated with that task.
  def remove_incomplete_tasks_status
    # PERFORMANCE: Use batch deletion to remove old statuses for incomplete tasks.
    # Instead of O(n) queries where n = number of incomplete tasks, we use a single
    # SQL query with a subquery that selects statuses beyond the limit per task.
    limit = ApplicationConfig.task_status_limit
    return unless limit.is_a?(Integer) && limit.positive?

    # Find task IDs that have more than the limit of statuses
    tasks_with_excess = Task.incomplete
                            .joins(:hashcat_statuses)
                            .group(:id)
                            .having("COUNT(hashcat_statuses.id) > ?", limit)
                            .pluck(:id)

    return if tasks_with_excess.empty?

    # For each task with excess statuses, delete the oldest ones beyond the limit
    # Use a more efficient approach by finding statuses to keep and deleting the rest
    tasks_with_excess.each_slice(100) do |task_ids|
      task_ids.each do |task_id|
        # Get the ID of the Nth newest status (the cutoff point)
        cutoff_status = HashcatStatus.where(task_id: task_id)
                                     .order(created_at: :desc)
                                     .offset(limit)
                                     .limit(1)
                                     .pick(:id)

        next unless cutoff_status

        # Delete all statuses older than the cutoff
        HashcatStatus.where(task_id: task_id)
                     .where("created_at <= (SELECT created_at FROM hashcat_statuses WHERE id = ?)", cutoff_status)
                     .delete_all
      end
    end
  end

  # Rebalances task assignments by checking for pending high-priority attacks
  # and attempting to preempt lower-priority tasks if needed.
  # Includes comprehensive error handling to ensure individual failures don't
  ##
  # Rebalances task assignments by ensuring high-priority attacks can acquire workers through preemption when needed.
  # Iterates incomplete attacks in high-priority campaigns that have no running tasks and, for each attack with remaining work (`uncracked_count > 0`), attempts to preempt lower-priority tasks. Per-attack errors are logged and skipped; any error during the overall rebalance is logged and not re-raised.
  def rebalance_task_assignments
    begin
      # Find high-priority attacks with no running tasks
      # Eager load campaign and hash_list to avoid N+1 queries when checking uncracked_count
      high_priority_attacks = Attack.incomplete
                                     .joins(:campaign)
                                     .includes(:campaign, campaign: :hash_list)
                                     .where(campaigns: { priority: Campaign.priorities[:high] })
                                     .where.not(id: Task.with_state(:running).select(:attack_id))

      high_priority_attacks.each do |attack|
        begin
          next if attack.uncracked_count.zero?

          # Attempt preemption
          TaskPreemptionService.new(attack).preempt_if_needed
        rescue StandardError => e
          Rails.logger.error(
            "[UpdateStatusJob] Error preempting tasks for attack #{attack.id} - " \
            "Error: #{e.class} - #{e.message} - #{Time.current}"
          )
          # Continue with next attack
        end
      end
    rescue StandardError => e
      Rails.logger.error(
        "[UpdateStatusJob] Error in rebalance_task_assignments - " \
        "Error: #{e.class} - #{e.message} - Backtrace: #{e.backtrace.first(5).join(' | ')} - #{Time.current}"
      )
      # Don't re-raise - this is a background job that should complete
    end
  end
end
