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

  # GET /campaigns/1 or /campaigns/1.json
  def show
    fresh_when(@campaign)
  end

  # GET /campaigns/new
  def new; end

  # GET /campaigns/1/edit
  def edit; end

  # POST /campaigns or /campaigns.json
  def create
    @hash_list = HashList.find(campaign_params[:hash_list_id])
    @campaign.project = @hash_list.project if @hash_list.present?

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

  # PATCH/PUT /campaigns/1 or /campaigns/1.json
  def update
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
    params.require(:campaign).permit(:name, :hash_list_id, :project_id, :priority)
  end

  def set_hash_lists
    @hash_lists = HashList.accessible_by(current_ability)
  end
end
