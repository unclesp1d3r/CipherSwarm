# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Api
  module V1
    module User
      class RuleListsController < Api::V1::UserBaseController
        load_and_authorize_resource

        # GET /rule_lists
        def index
          @rule_lists = RuleList.accessible_by(current_ability)
          render json: @rule_lists
        end

        # GET /rule_lists/:id
        def show
          render json: @rule_list
        end

        # POST /rule_lists
        def create
          @rule_list = RuleList.new(rule_list_params)
          @rule_list.creator = current_user
          if @rule_list.save
            render json: @rule_list, status: :created
          else
            render json: @rule_list.errors, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /rule_lists/:id
        def update
          if @rule_list.update(rule_list_params)
            render json: @rule_list
          else
            render json: @rule_list.errors, status: :unprocessable_entity
          end
        end

        # DELETE /rule_lists/:id
        def destroy
          @rule_list.destroy
          head :no_content
        end

        private

        def rule_list_params
          params.require(:rule_list).permit(:name, :description, :file, :line_count, :sensitive, project_ids: [])
        end
      end
    end
  end
end
