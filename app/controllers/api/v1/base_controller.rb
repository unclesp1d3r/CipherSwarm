# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# This class serves as the base controller for the API version 1.
# It provides common functionality and configurations for handling API requests,
# such as authentication, error handling, and ensuring security measures.
class Api::V1::BaseController < ApplicationController
  include TaskErrorHandling

  before_action :authenticate_agent # Authenticates the agent using a token.
  before_action :log_api_request_start # Logs the start of an API request with timestamp
  after_action :update_last_seen # Updates the last seen timestamp and IP address for the agent.
  after_action :log_api_request_complete # Logs the completion of an API request with duration

  # Catch-all error handler for unexpected exceptions
  # IMPORTANT: Must be registered FIRST so specific handlers below take precedence
  rescue_from StandardError do |e|
    agent_id = @agent&.id || "unknown"
    backtrace = e.backtrace.first(5).join("\n")
    Rails.logger.error("[APIError] UNHANDLED_ERROR - Agent #{agent_id} - #{request.method} #{request.path} - Error: #{e.class.name} - #{e.message} - Backtrace: #{backtrace} - #{Time.current}")
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  rescue_from NoMethodError do |e|
    agent_id = @agent&.id || "unknown"
    Rails.logger.error("[APIError] NO_METHOD_ERROR - Agent #{agent_id} - #{request.method} #{request.path} - Error: #{e.message} - #{Time.current}")
    render json: { error: "Invalid request" }, status: :unprocessable_content
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :bad_request
  end

  # Prevents CSRF attacks by zeroing the session. This is necessary for API requests.
  protect_from_forgery with: :null_session

  # Handles the case when a record is not found.
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

  # Handles JSON parsing errors in request bodies
  rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
    agent_id = @agent&.id || "unknown"
    Rails.logger.error("[APIError] JSON_PARSE_ERROR - Agent #{agent_id} - #{request.method} #{request.path} - Error: #{e.message} - #{Time.current}")
    render json: { error: "Invalid JSON format", details: e.message }, status: :bad_request
  end

  # Handles validation errors from ActiveRecord models
  rescue_from ActiveRecord::RecordInvalid do |e|
    agent_id = @agent&.id || "unknown"
    Rails.logger.error("[APIError] VALIDATION_ERROR - Agent #{agent_id} - #{request.method} #{request.path} - Model: #{e.record.class.name} - Errors: #{e.record.errors.full_messages.join(', ')} - #{Time.current}")
    render json: { error: "Validation failed", details: e.record.errors.full_messages }, status: :unprocessable_content
  end

  # Handles duplicate record errors (unique constraint violations)
  rescue_from ActiveRecord::RecordNotUnique do |e|
    agent_id = @agent&.id || "unknown"
    Rails.logger.error("[APIError] DUPLICATE_RECORD - Agent #{agent_id} - #{request.method} #{request.path} - Error: #{e.message} - #{Time.current}")
    render json: { error: "Duplicate record", details: e.message }, status: :conflict
  end

  private

  # Authenticates the agent using a token.
  # If the agent is successfully authenticated, the method returns true.
  # If the agent fails to authenticate, the method calls the `handle_bad_authentication` method.
  def authenticate_agent
    authenticate_agent_with_token || handle_bad_authentication
  end

  # Authenticates an agent using a token.
  #
  # This method is used to authenticate an agent by validating the provided token.
  # It retrieves the agent associated with the token and assigns it to the instance variable @agent.
  #
  # Example:
  #   authenticate_agent_with_token
  #
  # Returns:
  #   The agent associated with the token, or nil if no agent is found.
  def authenticate_agent_with_token
    authenticate_with_http_token do |token, _options|
      @agent = Agent.find_by(token: token)
      update_last_seen
      @agent # Explicitly return agent for authenticate_with_http_token
    end
  end

  # Handles bad authentication by rendering a JSON response with an error message.
  #
  # Example:
  #   handle_bad_authentication
  #
  # Returns:
  #   A JSON response with the message "Bad credentials" and a status of :unauthorized.
  def handle_bad_authentication
    render json: { error: "Bad credentials" }, status: :unauthorized
  end

  # Handles the case when a record is not found.
  #
  # This method is responsible for rendering a JSON response with a "Record not found" message
  # and setting the HTTP status code to 404 (Not Found).
  #
  # For task-related errors, this method provides enhanced error responses with reason codes
  # to help clients distinguish between different 404 scenarios and take appropriate action.
  #
  # Example usage:
  #   handle_not_found
  #
  # @return [void]
  def handle_not_found(exception = nil)
    # Check if this is a task-related error by examining the exception message
    if exception&.message&.match?(/Task/) || params[:controller]&.include?("tasks")
      # Provide enhanced error response for task not found errors
      task_id = params[:id]
      if @agent && task_id
        error_response = handle_task_not_found(task_id, @agent)
        render json: error_response, status: :not_found
        return
      end
    end

    # Default error response for non-task errors
    render json: { error: "Record not found" }, status: :not_found
  end

  # Logs the start of an API request.
  #
  # This method is called before each API request to log the request start time and details.
  # It stores the start time for duration calculation in the completion log.
  # Logs include agent ID (or "unknown" for authentication failures), HTTP method, path,
  # authentication status, and timestamp.
  #
  # Format: [APIRequest] START - Agent {agent_id} - {method} {path} - auth={status} - {timestamp}
  #
  # Example usage:
  #   log_api_request_start (called automatically via before_action)
  def log_api_request_start
    @api_request_start_time = Time.current
    agent_id = @agent&.id || "unknown"
    auth_status = @agent.present? ? "success" : "failed"
    Rails.logger.info("[APIRequest] START - Agent #{agent_id} - #{request.method} #{request.path} - auth=#{auth_status} - #{@api_request_start_time}")
  rescue StandardError => e
    # Ensure logging failures don't break the request
    Rails.logger.error("Failed to log API request start: #{e.message}")
  end

  # Logs the completion of an API request with duration.
  #
  # This method is called after each API request to log the response status and request duration.
  # Duration is calculated from the start time stored by log_api_request_start.
  # Logs include agent ID, HTTP method, path, status code, duration in milliseconds,
  # response size in bytes, and timestamp.
  #
  # Format: [APIRequest] COMPLETE - Agent {agent_id} - {method} {path} - Status {status} - Duration {duration_ms}ms - Size {size}bytes - {timestamp}
  #
  # Example usage:
  #   log_api_request_complete (called automatically via after_action)
  def log_api_request_complete
    agent_id = @agent&.id || "unknown"
    duration_ms = if @api_request_start_time
                    ((Time.current - @api_request_start_time) * 1000).round(2)
    else
                    "N/A"
    end
    response_size = response.get_header("Content-Length") || 0
    Rails.logger.info("[APIRequest] COMPLETE - Agent #{agent_id} - #{request.method} #{request.path} - Status #{response.status} - Duration #{duration_ms}ms - Size #{response_size}bytes - #{Time.current}")
  rescue StandardError => e
    # Ensure logging failures don't break the response
    Rails.logger.error("Failed to log API request completion: #{e.message}")
  end

  # Updates the last seen timestamp and IP address for the agent.
  #
  # This method is responsible for updating the `last_seen_at` and `last_ipaddress`
  # attributes of the `@agent` object. It sets the `last_seen_at` attribute to the
  # current time and the `last_ipaddress` attribute to the IP address of the request.
  #
  # Example usage:
  #   update_last_seen
  #
  # Note: The `@agent` object must be set before calling this method.
  def update_last_seen
    return unless @agent

    # PERFORMANCE: Throttle updates to reduce database writes on frequent API calls.
    # Only update if more than 30 seconds since last update or IP address changed.
    # This reduces updates from every API call to at most once per 30 seconds per agent.
    last_seen = @agent.last_seen_at
    ip_changed = @agent.last_ipaddress != request.remote_ip

    if last_seen.nil? || ip_changed || last_seen < 30.seconds.ago
      @agent.update(last_seen_at: Time.zone.now, last_ipaddress: request.remote_ip)
    end

    @agent.heartbeat unless @agent.active? # Only fire heartbeat when agent needs state change
  end
end
