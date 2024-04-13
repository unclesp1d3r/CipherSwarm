# frozen_string_literal: true

class Api::V1::BaseController < ApplicationController
  before_action :authenticate_agent # Authenticates the agent using a token.
  after_action :update_last_seen # Updates the last seen timestamp and IP address for the agent.

  rescue_from NoMethodError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :bad_request
  end

  # Prevents CSRF attacks by zeroing the session. This is necessary for API requests.
  protect_from_forgery with: :null_session

  # Handles the case when a record is not found.
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

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
  # Example usage:
  #   handle_not_found
  #
  # @return [void]
  def handle_not_found
    render json: { error: "Record not found" }, status: :not_found
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

    @agent.update(last_seen_at: Time.zone.now, last_ipaddress: request.remote_ip)
  end
end
