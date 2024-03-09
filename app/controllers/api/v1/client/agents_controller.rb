class Api::V1::Client::AgentsController < Api::V1::BaseController
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
                                  :operating_system, devices: [])
  end
end
