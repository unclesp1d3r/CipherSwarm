# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Api
  module V1
    module User
      class UsersController < Api::V1::UserBaseController
        load_and_authorize_resource

        # GET /users
        def index
          @users = User.all
          render json: @users
        end

        # GET /users/:id
        def show
          render json: @user
        end

        # POST /users
        def create
          @user = User.new(user_params)
          if @user.save
            render json: @user, status: :created
          else
            render json: @user.errors, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /users/:id
        def update
          if @user.update(user_params)
            render json: @user
          else
            render json: @user.errors, status: :unprocessable_entity
          end
        end

        # DELETE /users/:id
        def destroy
          @user.destroy
          head :no_content
        end

        private

        def user_params
          params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
        end
      end
    end
  end
end
