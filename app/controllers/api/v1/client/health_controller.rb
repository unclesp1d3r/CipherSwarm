# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Unauthenticated health check endpoint for agent clients.
#
# Inherits from ActionController::API instead of Api::V1::BaseController
# to bypass agent token authentication. Agents use this endpoint to
# verify server reachability before attempting authenticated requests.
#
# REASONING:
# - Why: Agents need a way to probe server availability without valid
#   credentials (e.g., during initial setup, circuit breaker half-open
#   probes, or connectivity diagnostics).
# - Alternatives considered:
#   - Rails built-in /up endpoint: exists but is not under the API namespace
#     and does not return JSON, making it unsuitable for agent clients.
#   - Authenticated health check: defeats the purpose — agents cannot check
#     connectivity if their token is expired or the auth system is down.
# - Decision: Minimal unauthenticated JSON endpoint under the client API
#   namespace, performing a lightweight inline database check.
class Api::V1::Client::HealthController < ActionController::API
  # GET /api/v1/client/health
  def index
    health = { status: "ok", api_version: 1, timestamp: Time.current.iso8601 }

    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      health[:database] = "healthy"
    rescue StandardError => e
      Rails.logger.error("[APIHealth] Database check failed: #{e.class.name} - #{e.message}")
      health[:database] = "unhealthy"
      health[:status] = "degraded"
    end

    status_code = health[:status] == "ok" ? :ok : :service_unavailable
    render json: health, status: status_code
  end
end
