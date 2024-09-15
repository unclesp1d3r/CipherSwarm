# frozen_string_literal: true

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
      # Check the online status of agents that have been offline for more than 30 minutes (customizable in the application config)
      Agent.without_state(:offline).inactive_for(ApplicationConfig.agent_considered_offline_time).each(&:check_online)

      # Remove old status for tasks in a finished state
      Task.finished.each { |task| task.hashcat_statuses.destroy_all }

      # Remove running status
      Task.incomplete.each { |task| task.remove_old_status }

      # Abandon tasks that have been running for more than 30 minutes without activity (customizable in the application config)
      Task.with_state(:running).inactive_for(ApplicationConfig.task_considered_abandoned_age).each { |task| task.abandon }
    end
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
end
