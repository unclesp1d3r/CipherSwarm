# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller for managing operations related to agents.
#
# Inherits from Api::V1::BaseController and provides actions to manage
# agents, such as showing, updating, handling heartbeat signals, shutting
# down agents, and submitting benchmarks or error reports.
class Api::V1::Client::AgentsController < Api::V1::BaseController
  # Renders the JSON representation of the agent.

  def show; end

  # Updates the agent with the specified parameters.
  #
  # Parameters:
  #   - agent_params: The parameters to update the agent with.
  #
  # Returns:
  #   The updated agent if the update was successful, otherwise returns the agent errors.
  def update
    # The name parameter is deprecated and will be removed in the future.
    # It has been replaced by host_name.
    # We'll just set the host_name to the name if it's not present.

    agent_params[:host_name] = agent_params[:name] if agent_params[:name].present?
    agent_params.delete(:name)

    return if @agent.update(agent_params)
    Rails.logger.error("[APIError] AGENT_UPDATE_FAILED - Agent #{@agent.id} - Errors: #{@agent.errors.full_messages.join(', ')} - #{Time.current}")
    render json: @agent.errors, status: :unprocessable_content
  end

  # If the agent is active, does nothing. Otherwise, renders the agent's state.
  # Accepts an optional activity parameter to track agent's current activity.
  def heartbeat
    # Update activity if the key is present in params (even if value is nil)
    if params.key?(:activity)
      previous_activity = @agent.current_activity
      @agent.current_activity = params[:activity]

      # Save activity separately to avoid blocking heartbeat on validation errors
      unless @agent.save
        Rails.logger.warn(
          "[AgentLifecycle] activity_update_failed: agent_id=#{@agent.id} activity=#{params[:activity]} " \
          "errors=#{@agent.errors.full_messages.join(', ')} timestamp=#{Time.zone.now}"
        )
        # Reset to previous activity on failure
        @agent.current_activity = previous_activity
        @agent.errors.clear
      else
        # Log activity changes for audit trail
        if previous_activity != @agent.current_activity
          Rails.logger.info(
            "[AgentLifecycle] activity_changed: agent_id=#{@agent.id} " \
            "activity_change=#{previous_activity || 'nil'}->#{@agent.current_activity || 'nil'} timestamp=#{Time.zone.now}"
          )
        end
      end
    end

    unless @agent.heartbeat
      Rails.logger.error(
        "[AgentLifecycle] heartbeat_failed: agent_id=#{@agent.id} state=#{@agent.state} " \
        "errors=#{@agent.errors.full_messages.join(', ')} timestamp=#{Time.zone.now}"
      )
      render json: { error: "Heartbeat state transition failed", details: @agent.errors.full_messages },
             status: :unprocessable_content
      return
    end

    # Log when agent transitions from offline to active/pending
    if @agent.state_previously_changed? && @agent.state_was == "offline"
      Rails.logger.info(
        "[AgentLifecycle] reconnect: agent_id=#{@agent.id} state_change=offline->#{@agent.state} " \
        "last_seen_at=#{@agent.last_seen_at} ip=#{@agent.last_ipaddress} timestamp=#{Time.zone.now}"
      )
    end

    # Log heartbeat failure if last_seen_at exceeds offline threshold
    offline_threshold = ApplicationConfig.agent_considered_offline_time.ago
    if @agent.last_seen_at.present? && @agent.last_seen_at < offline_threshold
      Rails.logger.warn(
        "[AgentLifecycle] heartbeat_threshold_exceeded: agent_id=#{@agent.id} state=#{@agent.state} " \
        "last_seen_at=#{@agent.last_seen_at} threshold=#{ApplicationConfig.agent_considered_offline_time} " \
        "threshold_time=#{offline_threshold} current_time=#{Time.zone.now} timestamp=#{Time.zone.now}"
      )
    end

    return if @agent.active?

    # if the agent isn't active, but has a set of benchmarks, we'll just say its fine.
    return if @agent.pending? && @agent.hashcat_benchmarks.present?
    render json: { state: @agent.state }, status: :ok
  end

  # Marks the agent as shutdown.
  def shutdown
    unless @agent.shutdown
      Rails.logger.error(
        "[AgentLifecycle] shutdown_failed: agent_id=#{@agent.id} state=#{@agent.state} " \
        "errors=#{@agent.errors.full_messages.join(', ')} timestamp=#{Time.zone.now}"
      )
      render json: { error: "Shutdown transition failed", details: @agent.errors.full_messages },
             status: :unprocessable_content
      return
    end

    Rails.logger.info(
      "[AgentLifecycle] shutdown_success: agent_id=#{@agent.id} state=#{@agent.state} timestamp=#{Time.zone.now}"
    )
    head :no_content
  end

  # Handles the submission of hashcat benchmarks for an agent.
  #
  # Validates each submitted benchmark entry and upserts valid records using
  # the (agent_id, hash_type, device) unique index. Invalid entries are logged
  # and skipped. Fires the `benchmarked` state machine event only when the
  # agent has at least one benchmark row after processing.
  #
  # @return [void]
  def submit_benchmark
    if params[:hashcat_benchmarks].nil?
      render json: { error: "No benchmarks submitted" }, status: :bad_request
      return
    end

    valid_records = build_valid_benchmark_records(params[:hashcat_benchmarks])

    write_success = false
    HashcatBenchmark.transaction do
      if valid_records.any?
        # rubocop:disable Rails/SkipsModelValidations -- pre-filtered above; upsert_all is intentional for idempotent bulk writes
        HashcatBenchmark.upsert_all(
          valid_records,
          unique_by: %i[agent_id hash_type device],
          update_only: %i[hash_speed runtime benchmark_date]
        )
        # rubocop:enable Rails/SkipsModelValidations
      end
      raise ActiveRecord::Rollback unless HashcatBenchmark.exists?(agent_id: @agent.id)
      raise ActiveRecord::Rollback unless @agent.benchmarked
      @agent.touch # rubocop:disable Rails/SkipsModelValidations -- upsert_all bypasses touch: true callback; explicit touch invalidates view caches
      write_success = true
    end

    if write_success
      head :no_content
      return
    end

    Rails.logger.error(
      "[APIError] BENCHMARK_SUBMISSION_FAILED - Agent #{@agent.id} - " \
      "Error: Failed to submit benchmarks - #{Time.current}"
    )
    render json: { error: "Failed to submit benchmarks" }, status: :unprocessable_content
  end

  # Handles the submission of error reports for an agent.
  #
  # This method performs the following steps:
  # 1. Checks if the agent is present. If not, returns a 404 error.
  # 2. Adjusts the severity parameter if it is "low" to "info".
  # 3. Removes any null bytes from the message parameter.
  # 4. Validates the presence of both message and severity parameters. If either is missing, returns a 400 error.
  # 5. Creates a new error record for the agent.
  # 6. Sets the metadata for the error record, ensuring it includes an error date.
  # 7. Sets the severity for the error record.
  # 8. If a task_id is provided, checks if the task exists for the agent. If not, adds additional info to the metadata.
  # 9. Attempts to save the error record. If unsuccessful, returns a 422 error with validation errors.
  def submit_error
    if @agent.blank?
      render json: { error: "Agent not found" }, status: :not_found
      return
    end

    # If the severity is low, we'll just set it to info.
    # This is because of an api change where low severity is now info.
    if params[:severity].present? && params[:severity] == "low"
      params[:severity] = "info"
    end

    # Here we're just removing any null bytes from the message. This is to prevent any weirdness.
    params[:message] = params[:message].to_s.delete("\u0000") if params[:message].present?

    unless params[:message].present? && params[:severity].present?
      render json: { error: "No error submitted" }, status: :bad_request
      return
    end

    if params[:metadata].present? && params[:metadata].to_json.bytesize > 10_000
      render json: { error: "Metadata too large (maximum 10,000 bytes)" }, status: :bad_request
      return
    end

    error_record = @agent.agent_errors.new
    error_record.message = params[:message]

    # At some point we will standardize the metadata format. For now, we'll allow anything, but if it's not JSON, we'll
    # just add the error date.
    if params[:metadata].blank?
      error_record.metadata = {
        error_date: Time.zone.now
      }
    else
      error_record.metadata = params[:metadata]
      error_record.metadata[:error_date] = Time.zone.now if error_record.metadata[:error_date].blank?
    end

    error_record.severity = params[:severity]

    if params[:task_id].present?
      if @agent.tasks.exists?(id: params[:task_id])
        error_record.task_id = params[:task_id]
      else
        error_record.metadata[:additional_info] = "Task not found"
      end
    end

    if error_record.save
      quarantine_campaign_if_fatal!(error_record)
      head :no_content
      return
    end
    Rails.logger.error("[APIError] ERROR_RECORD_SAVE_FAILED - Agent #{@agent.id} - Errors: #{error_record.errors.full_messages.join(', ')} - #{Time.current}")
    render json: error_record.errors, status: :unprocessable_content
  end

  private

  # Inspects the structured metadata from the agent and quarantines the
  # associated campaign when the error is definitively unrecoverable.
  #
  # Quarantine is triggered when:
  #   - metadata.other.retryable is false, AND
  #   - metadata.other.category is "hash_format" OR metadata.other.terminal is true
  #
  # @param error_record [AgentError] the saved error record
  # @return [void]
  def quarantine_campaign_if_fatal!(error_record)
    return if error_record.task_id.blank?

    metadata = error_record.metadata
    return unless metadata.is_a?(Hash)

    other = metadata.dig("other") || metadata.dig(:other)
    return unless other.is_a?(Hash)

    retryable = other["retryable"].nil? ? other[:retryable] : other["retryable"]
    return unless retryable == false

    category = other["category"] || other[:category]
    terminal = other["terminal"].nil? ? other[:terminal] : other["terminal"]
    return unless category == "hash_format" || terminal == true

    campaign = error_record.task&.attack&.campaign
    return unless campaign

    campaign.quarantine!(error_record.message)

    Rails.logger.info(
      "[AgentLifecycle] campaign_quarantined: campaign_id=#{campaign.id} agent_id=#{@agent.id} " \
      "task_id=#{error_record.task_id} reason=\"#{error_record.message}\" timestamp=#{Time.zone.now}"
    )
  rescue StandardError => e
    campaign_id = begin
      error_record.task.attack.campaign_id
    rescue NoMethodError
      nil
    end
    Rails.logger.error(
      "[AgentLifecycle] quarantine_failed: campaign_id=#{campaign_id} " \
      "agent_id=#{@agent.id} task_id=#{error_record.task_id} " \
      "error=#{e.class} - #{e.message} timestamp=#{Time.zone.now}"
    )
  end

  # Returns the permitted parameters for creating or updating an agent.
  def agent_params
    params.expect(agent: [:id, :name, :host_name, :client_signature, :operating_system, devices: [],
                                                                                        hashcat_benchmarks: []])
  end

  # Filters and converts raw benchmark params into hashes suitable for upsert_all.
  # Invalid entries (non-positive speed/runtime, negative hash_type/device) are
  # logged and skipped.
  #
  # @param benchmarks [Array<ActionController::Parameters>] raw benchmark entries
  # @return [Array<Hash>] validated records ready for upsert_all
  def build_valid_benchmark_records(benchmarks)
    now = Time.zone.now

    benchmarks.filter_map do |benchmark|
      hash_speed = Float(benchmark[:hash_speed], exception: false)
      runtime = Integer(benchmark[:runtime], exception: false)
      hash_type = Integer(benchmark[:hash_type], exception: false)
      device = Integer(benchmark[:device], exception: false)

      if hash_speed.nil? || runtime.nil? || hash_type.nil? || device.nil? ||
         hash_speed <= 0 || runtime <= 0 || hash_type.negative? || device.negative?
        Rails.logger.warn(
          "[APIError] BENCHMARK_INVALID_ENTRY - Agent #{@agent.id} - " \
          "hash_type=#{benchmark[:hash_type]} hash_speed=#{benchmark[:hash_speed]} " \
          "- skipped - #{Time.current}"
        )
        next
      end

      {
        agent_id: @agent.id,
        hash_type: hash_type,
        device: device,
        hash_speed: hash_speed,
        runtime: runtime,
        benchmark_date: now,
        created_at: now,
        updated_at: now
      }
    end
  end
end
