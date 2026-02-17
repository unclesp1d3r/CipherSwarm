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
        "Database Size" => format_bytes(check[:database_size])
      }
    when :redis
      details = { "Memory" => check[:used_memory], "Clients" => check[:connected_clients] }
      details["Hit Rate"] = "#{check[:hit_rate]}%" if check[:hit_rate]
      details
    when :minio
      { "Storage Used" => format_bytes(check[:storage_used]), "Buckets" => check[:bucket_count] }
    else
      {}
    end
  end

  def format_bytes(bytes)
    return nil unless bytes

    if bytes >= 1_073_741_824
      "#{(bytes.to_f / 1_073_741_824).round(2)} GB"
    elsif bytes >= 1_048_576
      "#{(bytes.to_f / 1_048_576).round(2)} MB"
    elsif bytes >= 1024
      "#{(bytes.to_f / 1024).round(2)} KB"
    else
      "#{bytes} B"
    end
  end

  def service_checks
    @health_checks.except(*NON_SERVICE_KEYS)
  end

  def service_name_for(key)
    SERVICE_NAMES[key] || key.to_s.humanize
  end
end
