# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class Api::V1::UserBaseController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user_with_token

  rescue_from CanCan::AccessDenied do |exception|
    render json: { error: exception.message }, status: :forbidden
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: { error: exception.message }, status: :not_found
  end

  private

  def authenticate_user_with_token
    authenticate_with_http_token do |token, _options|
      @current_user = User.find_by(token: token)
    end

    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end
end
