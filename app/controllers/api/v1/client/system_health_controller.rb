# frozen_string_literal: true

# SPDX-FileCopyrightText:  2026 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Authenticated system health endpoint for agent clients.
#
# Returns the same detailed health data shown on the web dashboard
# (PostgreSQL pool stats, Redis, Sidekiq, Storage) but via the agent
# API with bearer token auth.
#
# REASONING:
# - Why: Agents need programmatic access to system health data for
#   adaptive throttling (e.g., back off when pool waiting > 0) and
#   operational visibility without a browser.
# - Alternatives considered:
#   - Reuse /system_health.json: requires Devise session auth, agents
#     authenticate via bearer tokens and can't reach it.
#   - Expose via /metrics only: Prometheus format, not structured JSON,
#     requires Prometheus to be deployed.
# - Decision: Thin controller delegating to SystemHealthCheckService,
#   under the client API namespace with standard agent auth.
class Api::V1::Client::SystemHealthController < Api::V1::BaseController
  # GET /api/v1/client/system_health
  def index
    render json: SystemHealthCheckService.call
  end
end
