# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Api
  module V1
    module User
      class MaskListsController < Api::V1::UserBaseController
        load_and_authorize_resource

        # GET /mask_lists
        def index
          @mask_lists = MaskList.accessible_by(current_ability)
          render json: @mask_lists
        end

        # GET /mask_lists/:id
        def show
          render json: @mask_list
        end

        # POST /mask_lists
        def create
          @mask_list = MaskList.new(mask_list_params)
          @mask_list.creator = current_user
          if @mask_list.save
            render json: @mask_list, status: :created
          else
            render json: @mask_list.errors, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /mask_lists/:id
        def update
          if @mask_list.update(mask_list_params)
            render json: @mask_list
          else
            render json: @mask_list.errors, status: :unprocessable_entity
          end
        end

        # DELETE /mask_lists/:id
        def destroy
          @mask_list.destroy
          head :no_content
        end

        private

        def mask_list_params
          params.require(:mask_list).permit(:name, :description, :file, :sensitive, project_ids: [])
        end
      end
    end
  end
end
