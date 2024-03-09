class Api::V1::ClientController < Api::V1::BaseController
  # Retrieves the configuration for the client.
  #
  # Returns a JSON object containing the client's command parameters and API version.
  def configuration
    render json: { config: @agent.advanced_configuration, api_version: 1 }
  end

  # Authenticates the client.
  #
  # Renders a JSON response indicating successful authentication.
  #
  # Example:
  #   authenticate
  #
  # Returns:
  #   A JSON response with the "authenticated" key set to true and a status code of 200.
  def authenticate
    render json: { authenticated: true, agent_id: @agent.id }, status: 200
  end
end
