# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Api
  module V1
    module User
      class CampaignsController < Api::V1::UserBaseController
        load_and_authorize_resource

        # GET /campaigns
        def index
          @campaigns = Campaign.accessible_by(current_ability)
          render json: @campaigns
        end

        # GET /campaigns/:id
        def show
          render json: @campaign
        end

        # POST /campaigns
        def create
          @campaign = Campaign.new(campaign_params)
          if @campaign.save
            render json: @campaign, status: :created
          else
            render json: @campaign.errors, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /campaigns/:id
        def update
          if @campaign.update(campaign_params)
            render json: @campaign
          else
            render json: @campaign.errors, status: :unprocessable_entity
          end
        end

        # DELETE /campaigns/:id
        def destroy
          @campaign.destroy
          head :no_content
        end

        # POST /campaigns/:id/start
        def start
          @campaign = Campaign.find(params[:id])
          if @campaign.resume
            render json: @campaign
          else
            render json: @campaign.errors, status: :unprocessable_entity
          end
        end

        # POST /campaigns/:id/pause
        def pause
          @campaign = Campaign.find(params[:id])
          if @campaign.pause
            render json: @campaign
          else
            render json: @campaign.errors, status: :unprocessable_entity
          end
        end

        # POST /campaigns/:id/stop
        def stop
          @campaign = Campaign.find(params[:id])
          if @campaign.complete
            render json: @campaign
          else
            render json: @campaign.errors, status: :unprocessable_entity
          end
        end

        private

        def campaign_params
          params.require(:campaign).permit(:name, :hash_list_id, :project_id, :priority)
        end
      end
    end
  end
end
