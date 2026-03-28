# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# UpdateStatusJob is responsible for maintaining the status of agents and tasks in the system.
# It performs the following actions:
# - Checks the online status of agents that have been offline for more than a configurable amount of time.
# - Removes old status for tasks that are in a finished state.
# - Removes running status for incomplete tasks.
# - Cleans up agent error records older than the configured retention period.
# - Abandons tasks that have been running for more than a configurable amount of time without activity.
# - Rebalances task assignments for non-deferred (normal and high) priority campaigns via preemption.
#
# Runs within an explicit connection pool checkout to avoid leaking connections.
# Scheduled via sidekiq-cron (see config/schedule.yml, default: every 3 minutes).
# Executed with a high priority queue.
class UpdateStatusJob < ApplicationJob
  include AttackPreemptionLoop

  queue_as :high

  ##
  # Executes periodic status maintenance tasks within an explicit connection pool checkout.
  #
  # Runs the sequence of status-update operations: check agents' online status, remove
  # status records for finished and incomplete tasks, clean up old agent errors, abandon
  # inactive running tasks, and rebalance task assignments for non-deferred campaigns.
  # Individual sub-tasks rescue their own errors to prevent one failure from blocking
  # the rest; however, connection-level errors in rebalancing propagate for Sidekiq retry.
  def perform(*_args)
    ActiveRecord::Base.connection_pool.with_connection do
      check_agents_online_status
      remove_finished_tasks_status
      remove_incomplete_tasks_status
      cleanup_old_agent_errors
      abandon_inactive_tasks
      rebalance_task_assignments
    end
  end

  private

  def abandon_inactive_tasks
    Task.with_state(:running).inactive_for(ApplicationConfig.task_considered_abandoned_age).find_each(&:abandon)
  end

  ##
  # Removes agent error records older than the configured retention period.
  # Uses ApplicationConfig.agent_error_retention (default: 30 days).
  def cleanup_old_agent_errors
    deleted_count = AgentError.remove_old_errors
    if deleted_count.positive?
      Rails.logger.info("[AgentErrorCleanup] Removed #{deleted_count} agent errors older than #{ApplicationConfig.agent_error_retention}")
    end
  rescue StandardError => e
    Rails.logger.error(
      "[AgentErrorCleanup] Error cleaning up old agent errors: #{e.class} - #{e.message} - " \
      "Backtrace: #{Array(e.backtrace).first(5).join(' | ')}"
    )
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
  # Uses delete_all instead of destroy_all because:
  # - No destroy callbacks exist on HashcatStatus, DeviceStatus, or HashcatGuess
  # - ON DELETE CASCADE FKs handle dependent cleanup at the database level
  # - delete_all issues a single DELETE statement vs loading/destroying records individually
  def remove_finished_tasks_status
    deleted_count = HashcatStatus
                    .where(task_id: Task.finished.select(:id))
                    .delete_all

    if deleted_count.positive?
      Rails.logger.info("[StatusCleanup] Removed #{deleted_count} hashcat_statuses for finished tasks")
    end
  rescue StandardError => e
    Rails.logger.error(
      "[StatusCleanup] Error removing finished task statuses: #{e.class} - #{e.message} - " \
      "Backtrace: #{Array(e.backtrace).first(5).join(' | ')}"
    )
  end

  ##
  # Trims excess status entries for incomplete tasks using a single CTE-based DELETE.
  # Delegates to HashcatStatus.trim_excess_for_incomplete_tasks which uses a window function
  # to rank statuses per task and delete those beyond the configured limit.
  def remove_incomplete_tasks_status
    limit = ApplicationConfig.task_status_limit
    deleted_count = HashcatStatus.trim_excess_for_incomplete_tasks(limit: limit)
    if deleted_count.positive?
      Rails.logger.info("[StatusCleanup] Trimmed #{deleted_count} excess hashcat_statuses for incomplete tasks")
    end
  rescue StandardError => e
    Rails.logger.error(
      "[StatusCleanup] Error removing incomplete task statuses: #{e.class} - #{e.message} - " \
      "Backtrace: #{Array(e.backtrace).first(5).join(' | ')}"
    )
  end

  ##
  # Rebalances task assignments by ensuring non-deferred attacks can acquire workers through preemption when needed.
  # Iterates incomplete attacks in non-deferred (normal and high) priority campaigns that have no running tasks and,
  # for each attack with remaining work (`uncracked_count > 0`), attempts to preempt lower-priority tasks.
  # Per-attack errors are logged and skipped; connection-level errors propagate for Sidekiq retry.
  def rebalance_task_assignments
    # Find non-deferred priority attacks with no running tasks
    # Eager load campaign and hash_list to avoid N+1 queries when checking uncracked_count
    preemptable_attacks = Attack.awaiting_assignment
                                .joins(:campaign)
                                .includes(:campaign, campaign: :hash_list)
                                .where(campaigns: { priority: [Campaign.priorities[:normal], Campaign.priorities[:high]] })
                                .where.not(id: Task.with_state(:running).select(:attack_id))

    preempt_attacks(preemptable_attacks)
  end
end
