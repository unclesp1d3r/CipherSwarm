# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class Api::V1::User::AgentStatusController < Api::V1::UserBaseController
  load_and_authorize_resource :agent

  # GET /api/v1/user/agents/:id/status
  def show
    @agent = Agent.find(params[:id])
    @current_task = @agent.current_running_attack
    @hashcat_status = @current_task&.latest_status
    @device_statuses = @hashcat_status&.device_statuses

    render json: {
      agent: @agent,
      current_task: @current_task,
      hashcat_status: @hashcat_status,
      device_statuses: @device_statuses
    }
  end
end
