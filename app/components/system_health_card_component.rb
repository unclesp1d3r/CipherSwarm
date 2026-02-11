# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Renders a service status card for the system health dashboard.
#
# Displays service name, health status badge, latency measurement,
# and error message when unhealthy.
#
# == Options
# - service_name: (String, required) Human-readable service name (e.g., "PostgreSQL").
# - status: (Symbol, required) Service status (:healthy, :unhealthy, :checking).
# - latency: (Float, optional) Response latency in milliseconds.
# - error: (String, optional) Error message when status is :unhealthy.
class SystemHealthCardComponent < ApplicationViewComponent
  include BootstrapIconHelper

  option :service_name, required: true
  option :status, required: true
  option :latency, default: proc { nil }
  option :error, default: proc { nil }

  def status_variant
    case @status
    when :healthy
      "success"
    when :unhealthy
      "danger"
    when :checking
      "warning"
    else
      "secondary"
    end
  end

  def status_icon_name
    case @status
    when :healthy
      "check-circle-fill"
    when :unhealthy
      "x-circle-fill"
    when :checking
      "arrow-repeat"
    else
      "question-circle"
    end
  end

  def status_text
    @status.to_s.humanize
  end

  def latency_text
    return nil unless @latency

    "#{@latency} ms"
  end
end
