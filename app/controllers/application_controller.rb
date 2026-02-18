# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "pagy"

# The ApplicationController is the base controller from which all other controllers in the application inherit.
# It provides default methods for error handling, user parameter configuration, and pagination support.
#
# Key Features:
# - Extends from `ActionController::Base`, providing the foundation for handling HTTP requests.
# - Includes `Pagy::Backend` for efficient server-side pagination.
# - Configures Devise parameters using `configure_permitted_parameters` to allow customization during user authentication.
# - Implements a suite of rescue methods to handle various types of application errors gracefully.
#
# Rescue Behavior:
# - `bad_request`: Handles client-side bad request errors (400 status).
# - `not_acceptable`: Handles errors indicating unacceptable client requests (406 status).
# - `not_authorized`: Handles unauthorized access errors (401 status).
# - `resource_forbidden`: Handles forbidden resource access errors (403 status).
# - `resource_not_found`: Handles not found errors for resources (404 status).
# - `route_not_found`: Handles routing errors for non-existent URLs (404 status).
# - `unknown_error`: Handles unexpected internal server errors (500 status).
# - `unsupported_version`: Handles requests for unsupported resource formats (404 status).
# - Specific exceptions like `ActionController::RoutingError`, `ActiveRecord::RecordNotFound`, and `CanCan::AccessDenied` are rescued with tailored response methods.
#
# Supported Error Handlers:
# - Logs errors for debugging and analytics.
# - Renders appropriate templates or JSON responses based on request context.
#
# Devise Parameter Configuration:
# - Customizes the permitted parameters for Devise's sign-up, sign-in, and account update actions.
#
# Recommended Use:
# ApplicationController serves as a central place to manage global configuration, behaviors, and shared error handling logic,
# ensuring all child controllers benefit from consistent defaults.
class ApplicationController < ActionController::Base
  include Pagy::Backend # Adds support for pagination.
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from StandardError, with: :unknown_error # Handles unknown errors.
  rescue_from ActionController::RoutingError, with: :route_not_found # Handles routing errors.
  rescue_from ActionController::UnknownFormat, with: :bad_request # Handles unknown format errors.
  rescue_from ActionController::InvalidCrossOriginRequest, with: :bad_request # Handles invalid cross-origin requests.
  rescue_from ActionController::InvalidAuthenticityToken, with: :bad_request # Handles invalid authenticity tokens.
  rescue_from AbstractController::ActionNotFound, with: :route_not_found # Handles action not found errors.
  rescue_from ActionView::MissingTemplate, with: :bad_request # Handles missing template errors.
  rescue_from ActiveRecord::RecordNotFound, with: :resource_not_found # Handles record not found errors.
  rescue_from ActiveRecord::RecordNotSaved, with: :not_acceptable # Handles record not saved errors.
  rescue_from ActionController::RoutingError, with: :route_not_found # Handles routing errors.
  rescue_from AbstractController::DoubleRenderError, with: :bad_request # Handles double render errors.
  rescue_from CanCan::AccessDenied, with: :not_authorized # Handles access denied errors.

  # Handles a bad request error.
  #
  # This method logs the error message and backtrace, and then responds with an appropriate error status and format.
  #
  # @param error [String] The error message.
  #
  # @return [void]
  def bad_request(error)
    logger.error "bad_request #{error}"
    logger.error error.backtrace.join("\n") unless error.backtrace.nil?
    respond_to do |format|
      format.html { render template: "errors/bad_request", status: :bad_request }
      format.json { render json: { error: "Bad Request", status: 400 }, status: :bad_request }
      format.all { head :bad_request }
    end
  end

  def not_acceptable(error)
    logger.error "not_acceptable #{error}"
    logger.error error.backtrace.join("\n") unless error.backtrace.nil?
    respond_to do |format|
      format.html { render template: "errors/not_acceptable", status: :not_acceptable }
      format.json { render json: { error: "Not Acceptable", status: 406 }, status: :not_acceptable }
      format.all { head :not_acceptable }
    end
  end

  # Handles the case when a user is not authorized to access a certain resource.
  #
  # @param [Exception] error The error that occurred when trying to access the resource.
  #
  # @return [void]
  def not_authorized(error)
    logger.error "not_authorized #{error}"
    respond_to do |format|
      format.html { render template: "errors/not_authorized", status: :unauthorized }
      format.json { render json: { error: "Not Authorized", status: 401 }, status: :unauthorized }
      format.all { head :unauthorized }
    end
  end

  # Handles the case when a resource is forbidden for the current user.
  #
  # @param [Exception] error The error that occurred when accessing the resource.
  #
  # @return [void]
  def resource_forbidden(error)
    logger.error "resource_forbidden #{error}"
    respond_to do |format|
      format.html { render template: "errors/not_authorized", status: :forbidden }
      format.json { render json: { error: "Forbidden", status: 403 }, status: :forbidden }
      format.all { head :forbidden }
    end
  end

  # Handles the case when a resource is not found.
  #
  # @param [Exception] error The error that occurred when the resource was not found.
  def resource_not_found(error)
    logger.error "resource_not_found #{error}"
    respond_to do |format|
      format.html { render template: "errors/resource_not_found", status: :not_found }
      format.json { render json: { error: "Resource Not Found", status: 404 }, status: :not_found }
      format.all { head :not_found }
    end
  end

  # Handles the case when a route is not found.
  #
  # @param [Exception] error The error that occurred when the route was not found.
  #
  # @return [void]
  def route_not_found(error)
    logger.error "route_not_found #{error}"
    respond_to do |format|
      format.html { render template: "errors/route_not_found", status: :not_found }
      format.json { render json: { error: "Route Not Found" }, status: :not_found }
      format.all { head :not_found }
    end
  end

  def unknown_error(error)
    logger.error "unknown_error #{error}"
    logger.error error.backtrace.join("\n") unless error.backtrace.nil?
    respond_to do |format|
      format.html { render template: "errors/unknown_error", status: :internal_server_error }
      format.json { render json: { error: "Unknown Error", status: 500 }, status: :internal_server_error }
      format.all { head :internal_server_error }
    end
  end

  # Handles the case when an unsupported version is encountered.
  # This can happen when a client requests a response type that is not implemented by the action.
  # Such as asking for a PDF response from an action that only supports JSON.
  #
  # @param [Exception] error The error object representing the unsupported version.
  def unsupported_version(error)
    logger.error "unsupported_version #{error}"
    respond_to do |format|
      format.html { render template: "errors/unsupported_version", status: :not_found }
      format.json { render json: { error: "Unsupported Version", status: 404 }, status: :not_found }
      format.all { head :not_found }
    end
  end

  protected

  def configure_permitted_parameters
    added_attrs = %i[name email password password_confirmation remember_me]
    devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
    devise_parameter_sanitizer.permit :sign_in, keys: %i[name password]
    devise_parameter_sanitizer.permit :account_update, keys: added_attrs
  end
end
