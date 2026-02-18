# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller for managing Campaign resources.
#
# The CampaignsController handles actions related to creating, updating,
# viewing, editing, and deleting campaigns. It also provides additional
# utility actions for toggling campaign status and user preferences.
#
# Filters:
# - `before_action :authenticate_user!` ensures that only authenticated users access controller actions.
# - `load_and_authorize_resource` uses CanCanCan to authorize resource access.
# - `before_action :set_hash_lists` is executed for the actions `new`, `edit`, `create`, and `update`.
class CampaignsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  before_action :set_hash_lists, only: %i[new edit create update]

  # GET /campaigns or /campaigns.json
  def index
    @campaigns = @campaigns.by_priority
  end

  # GET /campaigns/1 or /campaigns/1.json
  def show
    fresh_when(@campaign)

    # Preload attacks with complexity ordering and eager-load associations used by views
    @attacks = @campaign.attacks.by_complexity.includes(tasks: :hashcat_statuses)

    # Precompute map for failed attacks to their latest error
    failed_attack_ids = @attacks.where(state: "failed").pluck(:id)
    @failed_attack_error_map = AgentError.latest_per_attack(failed_attack_ids)
  end

  def eta_summary
    render partial: "eta_summary", locals: { campaign: @campaign }
  end

  def recent_cracks
    render partial: "recent_cracks", locals: { campaign: @campaign }
  end

  def error_log
    errors_query = AgentError.joins(task: :attack)
                             .where(attacks: { campaign_id: @campaign.id })
                             .includes(task: :attack)
                             .order(created_at: :desc)
    @pagy, @campaign_errors = pagy(errors_query, limit: 50)
    render partial: "error_log", locals: { campaign: @campaign, campaign_errors: @campaign_errors, pagy: @pagy }
  end


  # GET /campaigns/new
  def new; end

  # GET /campaigns/1/edit
  def edit; end

  ##
  # Creates a new Campaign, associates its project from the supplied hash list when present,
  # enforces high-priority authorization if the submitted priority is "high", and responds
  # with a redirect on success or re-renders the form with errors on failure.
  # @note Expects campaign attributes in params (permitted by #campaign_params), including `hash_list_id` and `priority`.
  def create
    @hash_list = HashList.find(campaign_params[:hash_list_id])
    @campaign.project = @hash_list.project if @hash_list.present?
    @campaign.creator = current_user

    # Check high priority authorization if priority is high
    if campaign_params[:priority] == "high"
      authorize! :set_high_priority, @campaign
    end

    respond_to do |format|
      if @campaign.save
        format.html { redirect_to campaign_url(@campaign), notice: "Campaign was successfully created." }
        format.json { render :show, status: :created, location: @campaign }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @campaign.errors, status: :unprocessable_content }
      end
    end
  end

  ##
  # Updates the specified Campaign with permitted parameters.
  #
  # If the submitted priority equals "high", performs an authorization check for `:set_high_priority` on the campaign.
  # On success, redirects to the campaign page (HTML) or renders the campaign as JSON with status `ok`.
  # On failure, re-renders the edit form (HTML) or returns the campaign errors as JSON with status `unprocessable_content`.
  def update
    # Check high priority authorization if priority is high
    if campaign_params[:priority] == "high"
      authorize! :set_high_priority, @campaign
    end

    respond_to do |format|
      if @campaign.update(campaign_params)
        format.html { redirect_to campaign_url(@campaign), notice: "Campaign was successfully updated." }
        format.json { render :show, status: :ok, location: @campaign }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @campaign.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /campaigns/1 or /campaigns/1.json
  def destroy
    @campaign.destroy!

    respond_to do |format|
      format.html { redirect_to campaigns_url, notice: "Campaign was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def toggle_hide_completed_activities
    authorize! :read, current_user
    current_user.toggle_hide_completed_activities
    redirect_to campaigns_path
  end

  def toggle_paused
    @campaign = Campaign.find(params[:campaign_id])
    authorize! :update, @campaign
    if @campaign.paused?
      @campaign.resume
    else
      @campaign.pause
    end
  end

  private

  # Only allow a list of trusted parameters through.
  def campaign_params
    params.expect(campaign: %i[name hash_list_id project_id priority])
  end

  def set_hash_lists
    @hash_lists = HashList.accessible_by(current_ability).chronological
  end
end
