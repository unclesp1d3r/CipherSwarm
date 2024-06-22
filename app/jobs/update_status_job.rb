# frozen_string_literal: true

class UpdateStatusJob < ApplicationJob
  queue_as :high

  # Performs the update status job.
  #
  # This method is responsible for updating the status of tasks in the system.
  # It checks for tasks that are in the "running" state and abandons them if
  # their activity timestamp is older than 30 minutes. It also deletes the old
  # status of tasks that are in either the "running" or "exhausted" state.
  #
  # @param _args [Array] the arguments passed to the method (not used in this case)
  #
  # @return [void]
  def perform(*_args)
    ActiveRecord::Base.connection_pool.with_connection do
      # Check the online status of agents that have been offline for more than 30 minutes (customizable in the application config)
      Agent.without_state([:offline]).inactive_for(ApplicationConfig.agent_considered_offline_time).each(&:check_online)

      # Not sure if this is necessary, but it's here for now
      # Maybe we should just assume benchmarks are good unless manually checked?
      # Agent.with_state(:active).each do |agent|
      #   agent.check_benchmark_age if agent.needs_benchmark?
      # end

      # Remove old status for tasks in a finished state
      Task.successful.each { |task| task.hashcat_statuses.destroy_all }

      # Remove running status
      Task.incomplete.each { |task| task.remove_old_status }

      # Abandon tasks that have been running for more than 30 minutes without activity (customizable in the application config)
      Task.with_state(:running).inactive_for(ApplicationConfig.task_considered_abandoned_age).each { |task| task.abandon }
    end
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
    ActiveRecord::Base.connection.close
  end
end
