# frozen_string_literal: true

#
# The ClientController handles client-specific actions such as authentication and configuration retrieval.
#
# Actions:
# - authenticate: Authenticates the client and returns a JSON response with authentication status and agent ID.
# - configuration: Retrieves the configuration for the client.
class Api::V1::ClientController < Api::V1::BaseController
  # Authenticates the client and returns a JSON response with authentication status and agent ID.
  #
  # @return [JSON, nil] JSON response with authentication status and agent ID.
  def authenticate
    render json: { authenticated: true, agent_id: @agent.id }, status: :ok
  end

  # Retrieves the configuration for the client.
  def configuration; end
end
