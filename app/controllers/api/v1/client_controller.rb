# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller responsible for managing client-related operations in the v1 API namespace.
# Inherits from Api::V1::BaseController.
class Api::V1::ClientController < Api::V1::BaseController

  # Authenticates and responds with a success status and the associated agent ID.
  # This method renders a JSON response indicating the authentication state
  # and the ID of the currently assigned agent.
  #
  # @return [void] This method does not return any value but sends a JSON response.
  def authenticate
    render json: { authenticated: true, agent_id: @agent.id }, status: :ok
  end

  # Retrieves the configuration for the client.
  def configuration; end
end
