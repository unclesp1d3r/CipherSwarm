# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Displays system health status for core infrastructure services.
#
# Delegates health check execution to SystemHealthCheckService, which handles
# caching and lock-based stampede prevention.
class SystemHealthController < ApplicationController
  include ActionView::Helpers::NumberHelper

  SERVICE_NAMES = {
    postgresql: "PostgreSQL",
    redis: "Redis",
    minio: "MinIO",
    sidekiq: "Sidekiq"
  }.freeze

  # Keys that are metadata, not individual service checks
  NON_SERVICE_KEYS = %i[application checked_at].freeze

  before_action :authenticate_user!

  helper_method :service_name_for, :service_checks, :details_for

  def index
    authorize! :read, :system_health
    @health_checks = SystemHealthCheckService.call

    respond_to do |format|
      format.html
      format.json { render json: @health_checks }
    end
  end

  private

  def details_for(service_key, check)
    case service_key
    when :postgresql
      {
        "Connections" => check[:connection_count],
        "Database Size" => check[:database_size] ? number_to_human_size(check[:database_size]) : nil
      }
    when :redis
      details = { "Memory" => check[:used_memory], "Clients" => check[:connected_clients] }
      details["Hit Rate"] = "#{check[:hit_rate]}%" if check[:hit_rate]
      details
    when :minio
      { "Storage Used" => check[:storage_used] ? number_to_human_size(check[:storage_used]) : nil, "Buckets" => check[:bucket_count] }
    else
      {}
    end
  end

  def service_checks
    @health_checks.except(*NON_SERVICE_KEYS)
  end

  def service_name_for(key)
    SERVICE_NAMES[key] || key.to_s.humanize
  end
end
