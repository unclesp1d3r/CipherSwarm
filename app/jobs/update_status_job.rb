# frozen_string_literal: true

class UpdateStatusJob < ApplicationJob
  queue_as :low_priority

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
    # Remove old status for tasks in a finished state
    Task.includes(:hashcat_statuses).successful.each { |task| task.remove_old_status }

    # Abandon tasks that have been running for more than 30 minutes without activity
    Task.with_state(:running).inactive_for(30.minutes).each { |task| task.abandon! }
  end
end
