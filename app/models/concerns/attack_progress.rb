# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Provides methods for tracking attack progress and execution status.
#
# This concern extracts progress tracking logic from the Attack model to improve
# organization and testability.
#
# @example
#   attack.percentage_complete
#   # => 75.5
#
#   attack.executing_agent
#   # => "agent-001"
module AttackProgress
  extend ActiveSupport::Concern

  # Estimates the finish time of the attack.
  #
  # This method retrieves the first running task associated with the attack
  # and returns its estimated finish time.
  #
  # @return [Time, nil] The estimated finish time of the attack, or nil if no running task is found.
  def estimated_finish_time
    current_task&.estimated_finish_time
  end

  # Returns the name of the agent associated with the most recently updated running task.
  # The method looks for tasks that are in the 'running' state, orders them by the 'updated_at' timestamp in descending order,
  # and retrieves the agent's name from the first task in the list.
  #
  # @return [String, nil] the name of the agent or nil if no such task or agent exists.
  def executing_agent
    current_task&.agent&.name
  end

  # Calculates the percentage of completion for the running task.
  #
  # @return [Float] the progress percentage of the running task, or 0.00 if no task is running.
  def percentage_complete
    current_task&.progress_percentage || 0.00
  end

  ##
  # Generates a human-readable text for progress.
  #
  # @return [String, nil] the progress text.
  def progress_text
    current_task&.progress_text
  end

  # Calculates the duration between the start and end times.
  #
  # @return [Float, nil] the difference between end_time and start_time in seconds,
  #   or nil if either start_time or end_time is not set.
  def run_time
    start_time.nil? || end_time.nil? || start_time > end_time ? nil : end_time - start_time
  end

  private

  # Returns the current running task for the attack.
  #
  # This method retrieves the task associated with the attack that is in the 'running' state,
  # orders them by the 'updated_at' timestamp in descending order, and returns the first task in the list.
  #
  # @return [Task, nil] the current running task or nil if no such task exists.
  def current_task
    tasks.with_state(:running).order(updated_at: :desc).first
  end
end
