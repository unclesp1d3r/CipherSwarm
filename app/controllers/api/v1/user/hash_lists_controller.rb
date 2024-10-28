# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Api
  module V1
    module User
      class HashListsController < Api::V1::UserBaseController
        load_and_authorize_resource

        # GET /hash_lists
        def index
          @hash_lists = HashList.accessible_to(current_user)
          render json: @hash_lists
        end

        # GET /hash_lists/:id
        def show
          render json: @hash_list
        end

        # POST /hash_lists
        def create
          @hash_list = HashList.new(hash_list_params)
          if @hash_list.save
            render json: @hash_list, status: :created
          else
            render json: @hash_list.errors, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /hash_lists/:id
        def update
          if @hash_list.update(hash_list_params)
            render json: @hash_list
          else
            render json: @hash_list.errors, status: :unprocessable_entity
          end
        end

        # DELETE /hash_lists/:id
        def destroy
          @hash_list.destroy
          head :no_content
        end

        # GET /hash_lists/:id/download_pot
        def download_pot
          pot_data = @hash_list.cracked_list
          send_data pot_data, filename: "#{@hash_list.name}.pot", type: "text/plain"
        end

        # GET /hash_lists/:id/download_csv
        def download_csv
          csv_data = CSV.generate(headers: true) do |csv|
            csv << %w[hash_value plain_text machine_name user_name]
            @hash_list.hash_items.cracked.find_each do |item|
              csv << [item.hash_value, item.plain_text, item.metadata["machine_name"], item.metadata["user_name"]]
            end
          end
          send_data csv_data, filename: "#{@hash_list.name}.csv", type: "text/csv"
        end

        private

        def hash_list_params
          params.require(:hash_list).permit(:name, :description, :file, :line_count, :sensitive, :project_id, :hash_type_id)
        end
      end
    end
  end
end
