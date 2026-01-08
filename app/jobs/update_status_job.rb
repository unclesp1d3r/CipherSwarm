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
  #
  # This method ensures that the database connection is properly managed by using a connection pool and clearing active connections after execution.
  def perform(*_args)
    ActiveRecord::Base.connection_pool.with_connection do
      check_agents_online_status
      remove_finished_tasks_status
      remove_incomplete_tasks_status
      abandon_inactive_tasks
      pause_lower_priority_campaigns
    end
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  private

  def abandon_inactive_tasks
    Task.with_state(:running).inactive_for(ApplicationConfig.task_considered_abandoned_age).each { |task| task.abandon }
  end

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

  def pause_lower_priority_campaigns
    Campaign.pause_lower_priority_campaigns
  end

  def remove_finished_tasks_status
    Task.finished.each { |task| task.hashcat_statuses.destroy_all }
  end

  def remove_incomplete_tasks_status
    Task.incomplete.each { |task| task.remove_old_status }
  end
end
