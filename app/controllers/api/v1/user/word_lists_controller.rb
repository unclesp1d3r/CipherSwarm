# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Api
  module V1
    module User
      class WordListsController < Api::V1::UserBaseController
        load_and_authorize_resource

        # GET /word_lists
        def index
          @word_lists = WordList.accessible_by(current_ability)
          render json: @word_lists
        end

        # GET /word_lists/:id
        def show
          render json: @word_list
        end

        # POST /word_lists
        def create
          @word_list = WordList.new(word_list_params)
          @word_list.creator = current_user
          if @word_list.save
            render json: @word_list, status: :created
          else
            render json: @word_list.errors, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /word_lists/:id
        def update
          if @word_list.update(word_list_params)
            render json: @word_list
          else
            render json: @word_list.errors, status: :unprocessable_entity
          end
        end

        # DELETE /word_lists/:id
        def destroy
          @word_list.destroy
          head :no_content
        end

        private

        def word_list_params
          params.require(:word_list).permit(:name, :description, :file, :line_count, :sensitive, project_ids: [])
        end
      end
    end
  end
end
