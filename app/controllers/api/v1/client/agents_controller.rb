class Api::V1::Client::AgentsController < ApplicationController
  before_action :authenticate_agent
  protect_from_forgery with: :null_session

  # Renders the JSON representation of the agent.
  def show
    render json: @agent
  end

  # Updates the agent with the specified parameters.
  #
  # Parameters:
  #   - agent_params: The parameters to update the agent with.
  #
  # Returns:
  #   The updated agent if the update was successful, otherwise returns the agent errors.
  def update
    if @agent.update(agent_params)
      render json: @agent
    else
      render json: @agent.errors, status: :unprocessable_entity
    end
  end

  private

  # Returns the permitted parameters for creating or updating an agent.
  def agent_params
    params.require(:agent).permit(:name, :client_signature, :command_parameters,
                                  :devices, :operating_system)
  end

  # Authenticates the agent using the provided token.
  #
  # Params:
  # - token: A string representing the token used for authentication.
  #
  # Returns:
  # - If the agent is authenticated successfully, it sets the @agent instance variable.
  # - If the token is invalid, it renders a JSON response with an error message and a 403 status code.
  def authenticate_agent
    @agent = Agent.find_by(token: params[:token])
    if @agent.nil?
      render json: { error: "Invalid token" }, status: 403
    end
  end
end
