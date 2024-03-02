class Api::V1::ClientController < ApplicationController
  before_action :authenticate_token, only: [ :configuration, :authenticate ]
  protect_from_forgery with: :null_session

  # Retrieves the configuration for the client.
  #
  # Returns a JSON object containing the client's command parameters and API version.
  def configuration
    render json: { config: @agent.command_parameters, api_version: 1 }
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
    render json: { authenticated: true }, status: 200
  end

  private

  # Authenticates the token provided by the client.
  #
  # This method finds the agent with the given token and checks if it exists.
  # If the agent is not found, it returns a JSON response with an error message and a 403 status code.
  #
  # Example usage:
  #   authenticate_token
  #
  # Returns:
  #   - If the agent is found: assigns the agent to the instance variable @agent.
  #   - If the agent is not found: renders a JSON response with an error message and a 403 status code.
  def authenticate_token
    @agent = Agent.find_by(token: params[:token])
    if @agent.nil?
      render json: { error: "Invalid token" }, status: 403
    end
  end
end
