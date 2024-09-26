# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate_admin

    rescue_from CanCan::AccessDenied, with: :not_authorized # Handles access denied errors.

    def authenticate_admin
      authorize! :read, :admin_dashboard
    end

    def not_authorized(error)
      logger.error "not_authorized #{error}"
      respond_to do |format|
        format.html { render template: "errors/not_authorized", status: :unauthorized }
        format.json { render json: { error: "Not Authorized", status: 401 }, status: :unauthorized }
        format.all { render nothing: true, status: :unauthorized }
      end
    end

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end
  end
end
