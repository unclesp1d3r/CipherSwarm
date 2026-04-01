# frozen_string_literal: true

# SPDX-FileCopyrightText:  2026 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Prometheus metrics instrumentation via Yabeda.
#
# Opt-in: set METRICS_ENABLED=true to activate. When disabled, no metrics
# are collected or exported — zero overhead in environments that don't need it.
#
# Exposes:
# - Rails request metrics (yabeda-rails)
# - Sidekiq queue/job metrics (yabeda-sidekiq)
# - Puma thread/worker metrics (yabeda-puma-plugin, web processes only)
# - Custom ActiveRecord connection pool gauges
#
# Scraped by Prometheus at GET /metrics (see config/routes.rb).

return unless ENV["METRICS_ENABLED"] == "true"

require "yabeda/rails"
require "yabeda/sidekiq"
require "yabeda/puma/plugin" if defined?(Puma)
require "yabeda/prometheus"

Yabeda.configure do
  # -- ActiveRecord connection pool gauges --
  # These surface pool exhaustion before it causes request timeouts.
  # Updated on every Prometheus scrape via the collect block below.
  group :db_pool do
    gauge :size,
          tags: %i[pool_name],
          comment: "Total connection pool size"
    gauge :connections,
          tags: %i[pool_name],
          comment: "Current number of open connections"
    gauge :busy,
          tags: %i[pool_name],
          comment: "Connections currently checked out by threads"
    gauge :dead,
          tags: %i[pool_name],
          comment: "Connections that failed a health check"
    gauge :idle,
          tags: %i[pool_name],
          comment: "Connections available for checkout"
    gauge :waiting,
          tags: %i[pool_name],
          comment: "Threads blocked waiting for a connection"
  end

  # Collect runs in the Prometheus scrape request thread on each scrape.
  # Inner rescue: isolates per-pool failures so one bad pool doesn't blank all gauges.
  # Outer rescue: handles failure to enumerate pools at all (e.g., handler unavailable).
  collect do
    ActiveRecord::Base.connection_handler.each_connection_pool do |pool|
      stat = pool.stat
      pool_name = pool.db_config.name

      db_pool_size.set({ pool_name: pool_name }, stat[:size])
      db_pool_connections.set({ pool_name: pool_name }, stat[:connections])
      db_pool_busy.set({ pool_name: pool_name }, stat[:busy])
      db_pool_dead.set({ pool_name: pool_name }, stat[:dead])
      db_pool_idle.set({ pool_name: pool_name }, stat[:idle])
      db_pool_waiting.set({ pool_name: pool_name }, stat[:waiting])
    rescue StandardError => e
      Rails.logger.error("[Yabeda] Failed to collect metrics for pool #{pool.db_config&.name || 'unknown'}: #{e.class} - #{e.message}")
    end
  rescue StandardError => e
    Rails.logger.error("[Yabeda] Failed to enumerate connection pools: #{e.class} - #{e.message}")
  end
end

# Sidekiq processes don't run Puma/Rack, so they can't serve /metrics via the
# route mount. Instead, start a standalone WEBrick metrics server on a dedicated
# port. Web (Puma) processes use the Rack mount in routes.rb.
#
# Note: PROMETHEUS_EXPORTER_PORT (not PORT) is used to avoid conflicting with
# Puma's PORT=80 inside the Docker container.
if defined?(Sidekiq::CLI)
  begin
    raw_port = ENV.fetch("PROMETHEUS_EXPORTER_PORT", "9394")
    port = Integer(raw_port)
    ENV["PROMETHEUS_EXPORTER_PORT"] = port.to_s
    Yabeda::Prometheus::Exporter.start_metrics_server!
  rescue ArgumentError
    Rails.logger.error("[Yabeda] Invalid PROMETHEUS_EXPORTER_PORT=#{raw_port.inspect} — must be an integer. Metrics server not started.")
  rescue StandardError => e
    Rails.logger.error(
      "[Yabeda] Failed to start Sidekiq metrics server on port #{port}: #{e.class} - #{e.message}. " \
      "Sidekiq will continue without metrics export."
    )
  end
end
