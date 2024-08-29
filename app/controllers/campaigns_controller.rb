# frozen_string_literal: true

class CampaignsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource

  # GET /campaigns or /campaigns.json
  def index
    @campaigns = Campaign.accessible_by(current_ability).where(project_id: current_user.projects)
  end

  # GET /campaigns/1 or /campaigns/1.json
  def show; end

  # GET /campaigns/new
  def new; end

  # GET /campaigns/1/edit
  def edit; end

  # POST /campaigns or /campaigns.json
  def create
    @campaign = Campaign.new(campaign_params)
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
    params.require(:campaign).permit(:name, :hash_list_id, :project_id)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_campaign
    @campaign = Campaign.find(params[:id])
  end
end
