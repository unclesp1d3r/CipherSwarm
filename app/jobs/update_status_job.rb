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
  # REASONING:
  # - Why: Use destroy_all instead of delete_all to ensure dependent callbacks fire
  #   (device_statuses and hashcat_guess have dependent: :destroy, touch: true on task).
  # - Alternatives considered:
  #   1. delete_all (faster but skips callbacks, orphans dependent records)
  #   2. destroy_all on full set (chosen - ensures data integrity)
  #   3. in_batches.destroy_all (unnecessary complexity for typical volumes)
  # - Decision: Use in_batches.destroy_all for memory efficiency while preserving callbacks.
  # - Performance: Slightly slower than delete_all but maintains referential integrity.
  def remove_finished_tasks_status
    deleted_count = 0
    HashcatStatus.where(task_id: Task.finished.select(:id)).in_batches(of: 1000) do |batch|
      deleted_count += batch.destroy_all.size
    end
    if deleted_count.positive?
      Rails.logger.info("[StatusCleanup] Removed #{deleted_count} hashcat_statuses for finished tasks")
    end
  rescue StandardError => e
    Rails.logger.error("[StatusCleanup] Error removing finished task statuses: #{e.message}")
  end

  ##
  # Removes outdated status entries for tasks that are currently in the incomplete state.
  # For each incomplete task, purges any stale or expired status data associated with that task.
  def remove_incomplete_tasks_status
    # REASONING:
    # - Why: The previous O(n) approach loaded all incomplete tasks and called remove_old_status on each,
    #   resulting in n separate DELETE queries. With hundreds of tasks, this caused significant DB load.
    # - Alternatives considered:
    #   1. Single DELETE with window function (PostgreSQL-specific, complex)
    #   2. Batch processing in chunks (chosen - portable and efficient)
    #   3. Background job per task (overhead of job scheduling)
    # - Decision: Batch processing in chunks of 100 tasks balances memory usage with query efficiency.
    #   First query identifies tasks with excess statuses, then processes in batches.
    # - Performance: Reduces from O(n) queries to O(n/100) + O(tasks_with_excess) queries.
    # - Future: Consider PostgreSQL-specific optimization if this becomes a bottleneck.
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
    # Use composite ordering (created_at, id) to handle duplicate timestamps deterministically
    tasks_with_excess.each_slice(100) do |task_ids|
      task_ids.each do |task_id|
        # Get the cutoff point using composite ordering to handle duplicate timestamps
        cutoff_row = HashcatStatus.where(task_id: task_id)
                                  .order(created_at: :desc, id: :desc)
                                  .offset(limit)
                                  .limit(1)
                                  .pick(:created_at, :id)

        next unless cutoff_row

        cutoff_time, cutoff_id = cutoff_row

        # Delete all statuses older than the cutoff using deterministic condition
        # This handles duplicate timestamps by also comparing IDs
        HashcatStatus.where(task_id: task_id)
                     .where(
                       "created_at < ? OR (created_at = ? AND id <= ?)",
                       cutoff_time,
                       cutoff_time,
                       cutoff_id
                     )
                     .in_batches(of: 500, &:destroy_all)
      end
    end
  rescue StandardError => e
    Rails.logger.error("[StatusCleanup] Error removing incomplete task statuses: #{e.message}")
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
            "[TaskRebalance] Error preempting tasks for attack #{attack.id} - " \
            "Error: #{e.class} - #{e.message}"
          )
          # Continue with next attack
        end
      end
    rescue StandardError => e
      Rails.logger.error(
        "[TaskRebalance] Error in rebalance_task_assignments - " \
        "Error: #{e.class} - #{e.message} - Backtrace: #{e.backtrace.first(5).join(' | ')}"
      )
      # Don't re-raise - this is a background job that should complete
    end
  end
end
