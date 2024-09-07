# frozen_string_literal: true

class AgentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource

  # GET /agents or /agents.json
  def index; end

  # GET /agents/1 or /agents/1.json
  def show
    @pagy, @errors = pagy(@agent.agent_errors.order(created_at: :desc),
                          items: 10, anchor_string: 'data-remote="true"')
  end

  # GET /agents/new
  def new; end

  # GET /agents/1/edit
  def edit; end

  # POST /agents or /agents.json
  def create
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
    params.require(:agent)
          .permit(:client_signature, :command_parameters, :cpu_only, :ignore_errors,
                  :active, :trusted, :last_ipaddress, :last_seen_at, :name, :operating_system,
                  :token, :user_id,
                  advanced_configuration_attributes: %i[agent_update_interval use_native_hashcat backend_device],
                  project_ids: [])
  end
end
