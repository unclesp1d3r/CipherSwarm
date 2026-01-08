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
  def heartbeat
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

  #
  # This method handles the submission of hashcat benchmarks for an agent.
  # It expects the benchmarks to be provided in the `params[:hashcat_benchmarks]`.
  # If no benchmarks are submitted, it returns a bad request error.
  # The method processes each benchmark, creates a new HashcatBenchmark record,
  # and associates it with the agent. If the benchmarks are successfully saved,
  # it returns a no content response. Otherwise, it returns an unprocessable entity error.
  #
  # @return [void]
  def submit_benchmark
    # There's a weird bug where the JSON is sometimes in the body and as a param.
    if params[:hashcat_benchmarks].nil?
      render json: { error: "No benchmarks submitted" }, status: :bad_request
      return
    end

    benchmarks = params[:hashcat_benchmarks]

    write_success = false
    HashcatBenchmark.transaction do
      @agent.hashcat_benchmarks.clear
      benchmarks.each do |benchmark|
        @benchmark = HashcatBenchmark.build(
          benchmark_date: Time.zone.now,
          device: benchmark[:device],
          hash_speed: benchmark[:hash_speed],
          hash_type: benchmark[:hash_type],
          runtime: benchmark[:runtime],
          agent: @agent
        )
        @agent.hashcat_benchmarks << @benchmark if @benchmark.valid?
      end
      @agent.save!
      raise ActiveRecord::Rollback unless @agent.benchmarked
      write_success = true
    end

    if write_success
      head :no_content
      return
    end

    Rails.logger.error("[APIError] BENCHMARK_SUBMISSION_FAILED - Agent #{@agent.id} - Error: Failed to submit benchmarks - #{Time.current}")
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
      head :no_content
      return
    end
    Rails.logger.error("[APIError] ERROR_RECORD_SAVE_FAILED - Agent #{@agent.id} - Errors: #{error_record.errors.full_messages.join(', ')} - #{Time.current}")
    render json: error_record.errors, status: :unprocessable_content
  end

  private

  # Returns the permitted parameters for creating or updating an agent.
  def agent_params
    params.expect(agent: [:id, :name, :host_name, :client_signature, :operating_system, devices: [],
                                                                                        hashcat_benchmarks: []])
  end
end
