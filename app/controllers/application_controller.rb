class ApplicationController < ActionController::Base
  include Pagy::Backend # Adds support for pagination.
  rescue_from Exception, with: :unknown_error if Rails.env.production?
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
  # Handles the case when a user is not authorized to access a certain resource.
  #
  # @param [Exception] error The error that occurred when trying to access the resource.
  #
  # @return [void]
  def not_authorized(error)
    logger.error "not_authorized #{error}"
    respond_to do |format|
      format.html { render template: "errors/not_authorized", status: 401 }
      format.json { render json: { error: "Not Authorized", status: 401 }, status: 401 }
      format.all { render nothing: true, status: 401 }
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
      format.html { render template: "errors/not_authorized", status: 403 }
      format.json { render json: { error: "Forbidden", status: 403 }, status: 403 }
      format.all { render nothing: true, status: 403 }
    end
  end

  # Handles the case when a resource is not found.
  #
  # @param [Exception] error The error that occurred when the resource was not found.
  def resource_not_found(error)
    logger.error "resource_not_found #{error}"
    respond_to do |format|
      format.html { render template: "errors/resource_not_found", status: 404 }
      format.json { render json: { error: "Resource Not Found", status: 404 }, status: 404 }
      format.all { render nothing: true, status: 404 }
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
      format.html { render template: "errors/route_not_found", status: 404 }
      format.json { render json: { error: "Route Not Found" }, status: 404 }
      format.all { render nothing: true, status: 404 }
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
      format.html { render template: "errors/unsupported_version", status: 404 }
      format.json { render json: { error: "Unsupported Version", status: 404 }, status: 404 }
      format.all { render nothing: true, status: 404 }
    end
  end

  def not_acceptable(error)
    logger.error "not_acceptable #{error}"
    logger.error error.backtrace.join("\n") unless error.backtrace.nil?
    respond_to do |format|
      format.html { render template: "errors/not_acceptable", status: 406 }
      format.json { render json: { error: "Not Acceptable", status: 406 }, status: 406 }
      format.all { render nothing: true, status: 406 }
    end
  end

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
      format.html { render template: "errors/bad_request", status: 400 }
      format.json { render json: { error: "Bad Request", status: 400 }, status: 400 }
      format.all { render nothing: true, status: 400 }
    end
  end

  def unknown_error(error)
    logger.error "unknown_error #{error}"
    logger.error error.backtrace.join("\n") unless error.backtrace.nil?
    respond_to do |format|
      format.html { render template: "errors/unknown_error", status: 500 }
      format.json { render json: { error: "Unknown Error", status: 500 }, status: 500 }
      format.all { render nothing: true, status: 500 }
    end
  end
end
