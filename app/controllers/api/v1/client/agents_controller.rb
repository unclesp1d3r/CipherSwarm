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
    return if @agent.update(agent_params)
    render json: @agent.errors, status: :unprocessable_content
  end

  # If the agent is active, does nothing. Otherwise, renders the agent's state.
  def heartbeat
    @agent.heartbeat
    return if @agent.active?
    # if the agent isn't active, but has a set of benchmarks, we'll just say its fine.
    return if @agent.hashcat_benchmarks.present?
    render json: { state: @agent.state }, status: :ok
    nil
  end

  # Marks the agent as shutdown.
  def shutdown
    @agent.shutdown
    head :no_content
  end

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

    render json: @agent.errors, status: :unprocessable_content
  end

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
      task = @agent.tasks.find(params[:task_id])
      if task.blank?
        error_record.metadata[:additional_info] = "Task not found"
      else
        error_record.task = task
      end

    end

    return if error_record.save
    render json: error_record.errors, status: :unprocessable_content
  end

  private

  # Returns the permitted parameters for creating or updating an agent.
  def agent_params
    params.require(:agent).permit(:id, :name, :client_signature, :operating_system, devices: [],
                                                                                    hashcat_benchmarks: [])
  end
end
