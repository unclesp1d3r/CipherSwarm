# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# AgentsController provides actions for managing agents within the application.
# This controller handles CRUD operations, including listing agents, viewing details,
# creating, editing, updating, and deleting agents. It ensures users are authenticated
# and authorized to perform actions on agents.
#
# Before Actions:
# - `authenticate_user!`: Ensures the user is logged in before accessing any action.
# - `load_and_authorize_resource`: Loads the resource and applies authorization checks.
class AgentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource

  # GET /agents or /agents.json
  def index; end

  # GET /agents/cards
  # Returns agent cards for turbo frame lazy loading
  # Skip default authorization and use index authorization for this collection action
  skip_authorize_resource only: :cards
  def cards
    authorize! :index, Agent
    @agents = Agent.accessible_by(current_ability, :read)
    render partial: "agents/cards", locals: { agents: @agents }
  end

  # GET /agents/1 or /agents/1.json
  def show
    @pagy, @errors = pagy(:offset, @agent.agent_errors.order(created_at: :desc),
                          limit: 10, anchor_string: 'data-remote="true"')
  end

  # GET /agents/new
  def new; end

  # GET /agents/1/edit
  def edit; end

  # POST /agents or /agents.json
  def create
    # Since the agent is created by the user and hasn't checked in yet, we will set the host_name to the custom_label
    # if it is present. Otherwise, we will set it to a random string.
    # It will be updated when the agent checks in.
    @agent.host_name = @agent.custom_label.presence || SecureRandom.hex(8)
    # Allow admins to assign agents to other users, otherwise default to current_user
    @agent.user_id = @agent.user_id.presence || current_user.id

    respond_to do |format|
      if @agent.save
        format.html { redirect_to agent_url(@agent), notice: "Agent was successfully created." }
        format.json { render :show, status: :created, location: @agent }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @agent.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /agents/1 or /agents/1.json
  def update
    respond_to do |format|
      if @agent.update(agent_params)
        format.html { redirect_to agent_url(@agent), notice: "Agent was successfully updated." }
        format.json { render :show, status: :ok, location: @agent }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @agent.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /agents/1 or /agents/1.json
  def destroy
    @agent.destroy!

    respond_to do |format|
      format.html { redirect_to agents_url, notice: "Agent was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Only allow a list of trusted parameters through.
  def agent_params
    permitted = [:client_signature, :command_parameters, :cpu_only, :ignore_errors,
      :enabled, :trusted, :last_ipaddress, :last_seen_at, :custom_label, :operating_system,
      :token,
      advanced_configuration_attributes: %i[agent_update_interval use_native_hashcat backend_device opencl_devices],
      project_ids: []]
    # Allow admins to assign agents to users
    permitted << :user_id if current_user.admin?

    params.expect(agent: permitted)
  end
end
