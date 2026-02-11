# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Lograge configuration for structured logging in production.
# Replaces verbose Rails logs with single-line JSON entries per request.
# This enables easier parsing by log aggregation services (ELK, Datadog, etc.).

Rails.application.configure do
  # Enable in production for structured logging and in development for testing purposes
  config.lograge.enabled = Rails.env.production? || Rails.env.development?

  # Use JSON formatter for machine-readable logs
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Include additional context in each log entry
  config.lograge.custom_options = lambda do |event|
    options = {
      host: event.payload[:host],
      request_id: event.payload[:request_id],
      user_agent: event.payload[:user_agent],
      ip: event.payload[:ip],
      time: Time.zone.now.iso8601
    }

    # Include agent and task IDs from request parameters or controller instance variables
    if event.payload[:agent_id].present?
      options[:agent_id] = event.payload[:agent_id]
    end

    if event.payload[:task_id].present?
      options[:task_id] = event.payload[:task_id]
    end

    if event.payload[:attack_id].present?
      options[:attack_id] = event.payload[:attack_id]
    end

    if event.payload[:user_id].present?
      options[:user_id] = event.payload[:user_id]
    end

    # Include error context if present
    if event.payload[:exception].present?
      exception = event.payload[:exception]
      options[:exception_class] = exception.first
      options[:exception_message] = exception.second
    end

    if event.payload[:exception_object].present?
      options[:backtrace] = event.payload[:exception_object].backtrace&.first(5)
    end

    options.compact
  end

  # Keep original Rails log for errors (useful for debugging)
  config.lograge.keep_original_rails_log = false

  # Log to STDOUT for containerized environments
  config.lograge.logger = ActiveSupport::Logger.new($stdout)

  # Filter sensitive parameters from logs
  config.lograge.custom_payload do |controller|
    payload = {
      host: controller.request.host,
      request_id: controller.request.request_id,
      user_agent: controller.request.user_agent,
      ip: controller.request.remote_ip
    }

    # Extract agent_id from various sources
    if controller.respond_to?(:current_agent, true) && controller.send(:current_agent).present?
      payload[:agent_id] = controller.send(:current_agent).id
    elsif controller.params[:agent_id].present?
      payload[:agent_id] = controller.params[:agent_id]
    elsif controller.instance_variable_defined?(:@agent) && controller.instance_variable_get(:@agent).present?
      payload[:agent_id] = controller.instance_variable_get(:@agent).id
    end

    # Extract task_id from params or instance variable
    if controller.params[:id].present? && controller.controller_name == "tasks"
      payload[:task_id] = controller.params[:id]
    elsif controller.params[:task_id].present?
      payload[:task_id] = controller.params[:task_id]
    elsif controller.instance_variable_defined?(:@task) && controller.instance_variable_get(:@task).present?
      payload[:task_id] = controller.instance_variable_get(:@task).id
    end

    # Extract attack_id from params or instance variable
    if controller.params[:id].present? && controller.controller_name == "attacks"
      payload[:attack_id] = controller.params[:id]
    elsif controller.params[:attack_id].present?
      payload[:attack_id] = controller.params[:attack_id]
    elsif controller.instance_variable_defined?(:@attack) && controller.instance_variable_get(:@attack).present?
      payload[:attack_id] = controller.instance_variable_get(:@attack).id
    end

    # Extract user_id from Devise current_user (web UI requests)
    if controller.respond_to?(:current_user, true) && controller.send(:current_user).present?
      payload[:user_id] = controller.send(:current_user).id
    end

    payload
  end

  # Ignore certain paths from logging (health checks, assets, etc.)
  config.lograge.ignore_actions = [
    "Rails::HealthController#show"
  ]

  # Reduce noise by ignoring certain formats
  config.lograge.ignore_custom = lambda do |event|
    # Ignore asset requests in development if lograge is enabled there for testing
    event.payload[:path]&.start_with?("/assets")
  end
end
