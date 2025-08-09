# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# ErrorsController is responsible for handling various error responses and rendering
# appropriate messages and status codes for the client. This aids in providing a
# consistent error handling infrastructure for the application.
class ErrorsController < ApplicationController
  def bad_request
    render(status: :bad_request)
  end

  def internal_server_error
    render(status: :internal_server_error)
  end

  def not_acceptable
    render(status: :not_acceptable)
  end

  def not_authorized
    render(status: :unprocessable_content)
  end

  def resource_not_found
    render(status: :not_found)
  end

  def route_not_found
    render(status: :not_found)
  end

  def service_unavailable
    render(status: :internal_server_error)
  end

  def unknown_error
    render(status: :bad_request)
  end
end
