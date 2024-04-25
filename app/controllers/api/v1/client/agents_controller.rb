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

  # There's no reason to do anything here, as the before_action will update the agent.
  # This is just here to create an endpoint for the agent to hit.
  def heartbeat; end

  def last_benchmark
    render json: { last_benchmark_date: @agent.last_benchmark_date }
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
    return if @agent.hashcat_benchmarks.append(records)
    render json: { errors: @agent.errors }, status: :unprocessable_entity
  end

  private

  # Returns the permitted parameters for creating or updating an agent.
  def agent_params
    params.require(:agent).permit(:name, :client_signature, :operating_system, devices: [], hashcat_benchmarks: [])
  end
end
