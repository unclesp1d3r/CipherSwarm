# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Api
  module V1
    module User
      class AuthenticationController < Api::V1::UserBaseController
        skip_before_action :authenticate_user_with_token, only: [:create]

        # POST /api/v1/user/authenticate
        def create
          user = User.find_by(email: params[:email])

          if user&.valid_password?(params[:password])
            render json: { token: user.token }, status: :ok
          else
            render json: { error: "Invalid email or password" }, status: :unauthorized
          end
        end
      end
    end
  end
end
