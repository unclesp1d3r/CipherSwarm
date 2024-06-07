# frozen_string_literal: true

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
    if @agent.update(agent_params)
    else
      render json: { errors: @agent.errors }, status: :unprocessable_entity
    end
  end

  # If the agent is active, does nothing. Otherwise, renders the agent's state.
  def heartbeat
    return if @agent.active?
    render json: { state: @agent.state }, status: :ok
    nil
  end

  # Marks the agent as shutdown.
  def shutdown
    unless @agent.shutdown
      render json: { errors: @agent.errors }, status: :unprocessable_entity
    end
    @agent.tasks.each do |task|
      task.abandon
    end
  end

  def submit_benchmark
    # There's a weird bug where the JSON is sometimes in the body and as a param.
    if params[:_json].nil? && params[:hashcat_benchmarks].nil?
      render json: { errors: "No benchmarks submitted" }, status: :bad_request
      return
    end

    # If the JSON is the param, use that. Otherwise, use the JSON in the body.
    benchmarks = params[:hashcat_benchmarks] || params[:_json]

    records = []
    benchmarks.each do |benchmark|
      benchmark_record = HashcatBenchmark.new
      benchmark_record.benchmark_date = Time.zone.now
      benchmark_record.device = benchmark[:device].to_i
      benchmark_record.hash_speed = benchmark[:hash_speed].to_f
      benchmark_record.hash_type = benchmark[:hash_type].to_i
      benchmark_record.runtime = benchmark[:runtime].to_i
      records.append(benchmark_record)
    end
    if @agent.hashcat_benchmarks.append(records)
      return @agent.benchmarked
    end
    render json: { errors: @agent.errors }, status: :unprocessable_entity
  end

  def submit_error
    if @agent.blank?
      render json: { errors: "Agent not found" }, status: :not_found
      return
    end

    unless params[:message].present? && params[:severity].present?
      render json: { errors: "No error submitted" }, status: :bad_request
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
    end

    error_record.severity = params[:severity]
    if params[:task_id].present?
      task = @agent.tasks.find(params[:task_id])
      if task.blank?
        render json: { errors: "Task not found" }, status: :bad_request
        return
      end
      error_record.task = task
    end

    return if error_record.save
    render json: { errors: error_record.errors }, status: :unprocessable_entity
  end

  private

  # Returns the permitted parameters for creating or updating an agent.
  def agent_params
    params.require(:agent).permit(:id, :name, :client_signature, :operating_system, devices: [],
                                                                                    hashcat_benchmarks: [])
  end
end
