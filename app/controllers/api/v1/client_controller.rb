class Api::V1::ClientController < Api::V1::BaseController
  resource_description do
    short "Client"
    formats [ "json" ]
    error 401, "Unauthorized"
    error 404, "Not Found"
    header "Authorization", "The token to authenticate the agent with.", required: true
  end
  api!
  description "Obtains the configuration for the agent."
  returns code: 200, desc: "The configuration for the agent." do
    property :config, Hash, desc: "The configuration for the agent." do
      param_group :agent_advanced_configuration, Api::V1::BaseController
    end
    property :api_version, Integer, desc: "The version of the API."
    property :last_benchmark_date, Date, required: false, desc: "The date of the last benchmark."
  end

  def configuration
  end

  api!
  description "Authenticates the client. This is used to verify that the client is able to connect to the server."
  returns code: 200, desc: "The client was successfully authenticated." do
    property :authenticated, [ true, false ], desc: "Indicates whether the client was authenticated."
    property :agent_id, Integer, desc: "The ID of the agent that was authenticated."
  end
  returns code: 401, desc: "The client was not authenticated."
  error 401, "Unauthorized"

  def authenticate
    render json: { authenticated: true, agent_id: @agent.id }, status: 200
  end
end
