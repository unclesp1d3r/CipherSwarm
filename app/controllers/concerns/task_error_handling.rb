# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# TaskErrorHandling provides enhanced error handling and logging for task-related operations.
# This concern can be included in controllers to provide consistent task error responses
# and comprehensive logging for debugging task lifecycle issues.
module TaskErrorHandling
  extend ActiveSupport::Concern

  # Handles task not found errors with enhanced diagnostics and logging.
  #
  # This method provides detailed error responses based on different scenarios:
  # - Task never existed
  # - Task exists but is assigned to another agent
  # - Task was recently deleted
  # - Task was completed and removed
  #
  # @param task_id [String, Integer] The ID of the task that was not found
  # @param agent [Agent] The agent attempting to access the task
  # @return [Hash] Enhanced error response with reason code and optional details
  def handle_task_not_found(task_id, agent)
    # Check if task exists globally
    task = Task.find_by(id: task_id)

    if task.present?
      # Task exists but not assigned to this agent
      log_task_not_assigned(task_id, agent.id, task.agent_id)
      {
        error: "Record not found",
        reason: "task_not_assigned",
        details: "Task belongs to another agent"
      }
    elsif task_deleted_recently?(task_id)
      # Task was recently deleted
      log_task_deleted(task_id, agent.id)
      {
        error: "Record not found",
        reason: "task_deleted",
        details: "Task was removed when attack was abandoned or completed"
      }
    else
      # Task never existed or ID is invalid
      log_task_never_existed(task_id, agent.id)
      {
        error: "Record not found",
        reason: "task_invalid",
        details: "Task ID does not exist"
      }
    end
  end

  # Logs task access attempts for debugging and audit purposes.
  #
  # @param agent_id [Integer] The ID of the agent accessing the task
  # @param task_id [String, Integer] The ID of the task being accessed
  # @param request [Hash] Request details containing :method and :path
  # @param success [Boolean] Whether the task lookup was successful
  def log_task_access(agent_id, task_id, request, success)
    outcome = success ? "SUCCESS" : "FAILED"
    method = request[:method] || request[:verb]
    path = request[:path]
    Rails.logger.info(
      "[TaskAccess] Agent #{agent_id} - Task #{task_id} - #{method} #{path} - #{outcome} - #{Time.zone.now}"
    )
  end

  # Checks if a task ID likely belonged to a recently deleted task.
  #
  # Uses heuristics to determine if the task ID falls within the range of
  # recently created tasks, indicating it was likely deleted rather than
  # never having existed.
  #
  # @param task_id [String, Integer] The ID of the task to check
  # @param time_window_hours [Integer] Hours to look back for recent tasks (default: 24)
  # @return [Boolean] true if the task was likely recently deleted
  def task_deleted_recently?(task_id, time_window_hours: 24)
    return false if task_id.blank? || task_id.to_i <= 0

    # Check if task ID is within range of recently created tasks
    recent_task_ids = Task.where("created_at > ?", time_window_hours.hours.ago).pluck(:id)
    return false if recent_task_ids.empty?

    min_recent_id = recent_task_ids.min
    max_recent_id = recent_task_ids.max

    # If task_id falls within the range of recent task IDs, it was likely recently deleted
    task_id.to_i.between?(min_recent_id, max_recent_id)
  end

  # Logs task state transitions with context.
  #
  # @param options [Hash] Options hash containing state change information
  # @option options [Integer] :task_id The ID of the task
  # @option options [Integer] :agent_id The ID of the agent
  # @option options [Integer] :attack_id The ID of the attack
  # @option options [String] :from_state The previous state
  # @option options [String] :to_state The new state
  # @option options [Hash] :context Additional context information (default: {})
  def log_task_state_change(options)
    context = options[:context] || {}
    context_str = context.map { |k, v| "#{k}=#{v}" }.join(", ")
    Rails.logger.info(
      "[TaskStateChange] Task #{options[:task_id]} - Agent #{options[:agent_id]} - Attack #{options[:attack_id]} - " \
      "#{options[:from_state]} -> #{options[:to_state]} - #{context_str} - #{Time.zone.now}"
    )
  end

  private

  # Logs when a task is not assigned to the requesting agent.
  def log_task_not_assigned(task_id, requesting_agent_id, actual_agent_id)
    Rails.logger.warn(
      "[TaskNotFound] Task #{task_id} - Requested by Agent #{requesting_agent_id} - " \
      "Assigned to Agent #{actual_agent_id} - Reason: task_not_assigned - #{Time.zone.now}"
    )
  end

  # Logs when a task was deleted.
  def log_task_deleted(task_id, agent_id)
    Rails.logger.warn(
      "[TaskNotFound] Task #{task_id} - Agent #{agent_id} - Reason: task_deleted - " \
      "Task was removed when attack was abandoned or completed - #{Time.zone.now}"
    )
  end

  # Logs when a task never existed.
  def log_task_never_existed(task_id, agent_id)
    Rails.logger.warn(
      "[TaskNotFound] Task #{task_id} - Agent #{agent_id} - Reason: task_invalid - " \
      "Task ID does not exist - #{Time.zone.now}"
    )
  end
end
