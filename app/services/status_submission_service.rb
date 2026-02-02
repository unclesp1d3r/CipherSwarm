# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# StatusSubmissionService handles the business logic for processing task status updates.
#
# This service encapsulates the complex logic previously in TasksController#submit_status,
# including:
# - Creating HashcatStatus records with associated guesses and device statuses
# - Updating task activity timestamps
# - Handling task state transitions based on status
#
# REASONING:
# - Extracted ~60 lines of nested object creation from TasksController for clarity.
# - Complex param handling and state transitions benefit from isolated testing.
# Alternatives Considered:
# - Keep in controller: Makes submit_status action too complex with nested builds.
# - Use accepts_nested_attributes_for: Less control over error handling and validation order.
# - Form object: Would still need service for state transition logic.
# Decision:
# - Service object with Result Struct provides clear success/failure contract.
# - Uses transaction to ensure atomicity between status save and task state transition.
# Performance Implications:
# - Single transaction wraps status save and task accept for consistency.
# - Device statuses are built in-memory before save to minimize DB round-trips.
# Future Considerations:
# - Could batch status submissions for high-frequency updates.
# - Consider extracting device status handling if it becomes complex.
#
# @example Basic usage
#   result = StatusSubmissionService.new(
#     task: task,
#     status_params: {
#       original_line: "...",
#       session: "session_name",
#       hashcat_guess: { ... },
#       device_statuses: [ ... ]
#     }
#   ).call
#
#   case result.status
#   when :ok then head :no_content
#   when :stale then head :accepted
#   when :paused then head :gone
#   when :error then render json: { error: result.error }, status: :unprocessable_content
#   end
#
class StatusSubmissionService
  # Result object for service outcomes
  Result = Struct.new(:status, :error, :error_type, keyword_init: true) do
    def success?
      %i[ok stale paused].include?(status)
    end
  end

  # @return [Task] the task receiving the status update
  attr_reader :task

  # @return [Hash] the status parameters
  attr_reader :status_params

  # Initializes a new StatusSubmissionService.
  #
  # @param task [Task] the task receiving the status update
  # @param status_params [Hash] the permitted status parameters
  def initialize(task:, status_params:)
    @task = task
    @status_params = status_params
  end

  # Processes the status submission.
  #
  # @return [Result] the result of the operation
  def call
    update_activity_timestamp
    build_result = build_status
    return build_result if build_result.is_a?(Result)

    save_and_accept_status(build_result)
  end

  private

  # Updates the task's activity timestamp.
  def update_activity_timestamp
    task.update(activity_timestamp: Time.zone.now)
  end

  # Builds the HashcatStatus with associated records.
  #
  # @return [HashcatStatus, Result] the built status or an error result
  def build_status
    status = task.hashcat_statuses.build(status_attributes)

    guess_result = attach_hashcat_guess(status)
    return guess_result if guess_result.is_a?(Result)

    device_result = attach_device_statuses(status)
    return device_result if device_result.is_a?(Result)

    status
  end

  # Extracts status attributes from params.
  #
  # @return [Hash] the status attributes
  def status_attributes
    {
      original_line: status_params[:original_line],
      session: status_params[:session],
      time: status_params[:time],
      status: status_params[:status],
      target: status_params[:target],
      progress: status_params[:progress],
      restore_point: status_params[:restore_point],
      recovered_hashes: status_params[:recovered_hashes],
      recovered_salts: status_params[:recovered_salts],
      rejected: status_params[:rejected],
      time_start: status_params[:time_start],
      estimated_stop: status_params[:estimated_stop]
    }
  end

  # Attaches the hashcat guess to the status.
  #
  # @param status [HashcatStatus] the status to attach the guess to
  # @return [nil, Result] nil on success, error result on failure
  def attach_hashcat_guess(status)
    guess_params = status_params[:hashcat_guess]
    if guess_params.present?
      status.hashcat_guess = HashcatGuess.new(guess_params)
      nil
    else
      Result.new(status: :error, error: "Guess not found", error_type: :guess_not_found)
    end
  end

  # Attaches device statuses to the status.
  #
  # @param status [HashcatStatus] the status to attach device statuses to
  # @return [nil, Result] nil on success, error result on failure
  def attach_device_statuses(status)
    device_statuses = status_params[:device_statuses] || status_params[:devices]
    if device_statuses.present?
      device_statuses.each do |device_params|
        status.device_statuses << DeviceStatus.new(device_params)
      end
      nil
    else
      Result.new(status: :error, error: "Device Statuses not found", error_type: :device_statuses_not_found)
    end
  end

  # Saves the status and accepts it on the task within a transaction.
  # This ensures atomicity: if accept_status fails, the status save is rolled back.
  #
  # @param status [HashcatStatus] the status to save
  # @return [Result] the result of the operation
  def save_and_accept_status(status)
    accept_result = nil

    Task.transaction do
      status.save!
      accept_result = accept_status_on_task
      raise ActiveRecord::Rollback if accept_result.status == :error
    end

    accept_result
  rescue ActiveRecord::RecordInvalid => e
    Result.new(
      status: :error,
      error: e.record.errors.full_messages.join(", "),
      error_type: :save_failed
    )
  end

  # Accepts the status on the task and determines the response status.
  #
  # @return [Result] the result based on task state
  def accept_status_on_task
    unless task.accept_status
      return Result.new(
        status: :error,
        error: task.errors.full_messages.join(", "),
        error_type: :accept_failed
      )
    end

    determine_response_status
  end

  # Determines the appropriate response status based on task state.
  #
  # @return [Result] the result with appropriate status
  def determine_response_status
    if task.stale
      Result.new(status: :stale)
    elsif task.paused?
      Result.new(status: :paused)
    else
      Result.new(status: :ok)
    end
  end
end
