# frozen_string_literal: true

class AgentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_agent, only: %i[ show edit update destroy ]
  load_and_authorize_resource
  # GET /agents or /agents.json
  def index
  end

  # GET /agents/1 or /agents/1.json
  def show; end

  # GET /agents/new
  def new
    @agent = Agent.new
  end

  # GET /agents/1/edit
  def edit; end

  # POST /agents or /agents.json
  def create
    @agent = Agent.new(agent_params)

    respond_to do |format|
      if @agent.save
        format.html { redirect_to agent_url(@agent), notice: "Agent was successfully created." }
        format.json { render :show, status: :created, location: @agent }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
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
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
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
                  :token, :user_id, project_ids: [])
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_agent
    @agent = Agent.accessible_by(current_ability).find(params[:id])
  end
end
