# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Displays system health status for core infrastructure services.
#
# Delegates health check execution to SystemHealthCheckService, which handles
# caching and lock-based stampede prevention.
class SystemHealthController < ApplicationController
  SERVICE_NAMES = {
    postgresql: "PostgreSQL",
    redis: "Redis",
    minio: "MinIO",
    sidekiq: "Sidekiq"
  }.freeze

  before_action :authenticate_user!

  helper_method :service_name_for

  def index
    authorize! :read, :system_health
    @health_checks = SystemHealthCheckService.call
  end

  private

  def service_name_for(key)
    SERVICE_NAMES[key] || key.to_s.humanize
  end
end
