class Api::V1::Client::AgentsController < Api::V1::BaseController
  # Renders the JSON representation of the agent.

  resource_description do
    short "Client Agents"
    formats [ "json" ]
    description "The Client Agents API allows you to create, read, update, and delete agents."
    error 400, "Bad request. The request was invalid."
    error 401, "Unauthorized. The request was not authorized."
    error 404, "Not found. The requested resource was not found."
    header "Authorization", "The token to authenticate the agent with.", required: true
  end

  def_param_group :agent do
    param :id, :number, required: true, desc: "The agent's unique identifier."
    param :name, String, required: true, desc: "The agent's hostname."
    param :client_signature, String, required: true, desc: "The agent's client signature."
    property :command_parameters, String, desc: "The agent's command parameters."
    property :ignore_errors, [ true, false ], desc: "If true, the agent will ignore errors and continue. If false, the agent will stop on error."
    property :cpu_only, [ true, false ], desc: "If true, the agent will only use the CPU. Otherwise, the agent will use the GPU."
    property :trusted, [ true, false ], desc: "If true, the agent can be used to process items marked as sensitive."
    param :operating_system, String, desc: "The agent's operating system. This be a single word, such as 'windows', 'linux', or 'darwin'."
    param :devices, Array, desc: "The agent's GPU devices."
    property :advanced_configuration, Hash, desc: "The agent's advanced configuration." do
      param_group :agent_advanced_configuration, Api::V1::BaseController
    end
  end

  api! "Returns an agent."
  returns code: 200, desc: "The agent." do
    param_group :agent
  end
  error :not_found, "The agent was not found."

  def show
  end

  # Updates the agent with the specified parameters.
  #
  # Parameters:
  #   - agent_params: The parameters to update the agent with.
  #
  # Returns:
  #   The updated agent if the update was successful, otherwise returns the agent errors.
  api! "Updates the agent with the specified parameters."
  param_group :agent
  param :agent, Hash # This is here to deal with a apipie bug.
  returns code: 200, desc: "The agent was successfully updated." do
    param_group :agent
  end
  returns code: :unprocessable_entity, desc: "The agent was not updated." do
    property :errors, String, desc: "The error message."
  end
  error :unprocessable_entity, "The agent was not updated."
  error :not_found, "The agent was not found."

  def update
    if @agent.update(agent_params)
    else
      render json: { errors: @agent.errors }, status: :unprocessable_entity
    end
  end

  api! "Submits benchmark data for the agent."
  param :id, :number, required: true, desc: "The ID of the agent to submit the benchmark data for."
  param :hashcat_benchmarks, Array, required: true, desc: "The hashcat benchmarks to submit for the agent." do
    param :hash_type, :number, desc: "The hash type of the benchmark. This should be the hashcat hash type number."
    param :runtime, :number, desc: "The time taken to complete the benchmark. In milliseconds."
    param :hash_speed, String, desc: "The speed of the benchmark. In hashes per second."
    param :device, :number, desc: "The device used for the benchmark."
  end
  returns code: 200, desc: "The benchmark data was successfully submitted."
  returns code: :unprocessable_entity, desc: "The benchmark data was not submitted." do
    property :errors, String, desc: "The error message."
  end
  error :unprocessable_entity, "The benchmark data was not submitted."
  error :not_found, "The agent was not found."

  def submit_benchmark
    params[:hashcat_benchmarks].each do |benchmark|
      benchmark_record = HashcatBenchmark.new
      benchmark_record.benchmark_date = Time.zone.now
      benchmark_record.device = benchmark[:device].to_i
      benchmark_record.hash_speed = benchmark[:hash_speed].to_f
      benchmark_record.hash_type = benchmark[:hash_type].to_i
      benchmark_record.runtime = benchmark[:runtime].to_i
      unless @agent.hashcat_benchmarks.append(benchmark_record)
        render json: { errors: @agent.errors }, status: :unprocessable_entity
        return
      end
    end
  end

  api! "Updates the last seen timestamp and IP address for the agent."
  param :id, :number, required: true, desc: "The ID of the agent to update the last seen timestamp and IP address for."
  returns code: 200, desc: "The agent's last seen timestamp and IP address were successfully updated."
  error :not_found, "The agent was not found."

  def heartbeat
  end

  api! "Returns the last benchmark date for the agent."
  param :id, :number, required: true, desc: "The ID of the agent to get the last benchmark date for."
  returns code: 200, desc: "The last benchmark date for the agent." do
    property :last_benchmark_date, DateTime, desc: "The last benchmark date for the agent."
  end
  error :not_found, "The agent was not found."

  def last_benchmark
  end

  private

  # Returns the permitted parameters for creating or updating an agent.
  def agent_params
    params.require(:agent).permit(:name, :client_signature, :command_parameters,
                                  :operating_system, devices: [], hashcat_benchmarks: [])
  end
end
