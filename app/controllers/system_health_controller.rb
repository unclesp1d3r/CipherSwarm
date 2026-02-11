# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Displays system health status for core infrastructure services.
#
# Performs health checks against PostgreSQL, Redis, MinIO (ActiveStorage),
# and Sidekiq. Results are cached for 1 minute with a Redis-based lock
# to prevent cache stampede when multiple requests arrive simultaneously.
class SystemHealthController < ApplicationController
  CACHE_KEY = "system_health_checks"
  LOCK_KEY = "system_health_check_lock"
  CACHE_TTL = 1.minute
  LOCK_TTL = 10 # seconds
  CHECK_TIMEOUT = 5 # seconds
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
    @health_checks = fetch_health_checks
  end

  private

  def service_name_for(key)
    SERVICE_NAMES[key] || key.to_s.humanize
  end

  def fetch_health_checks
    cached = Rails.cache.read(CACHE_KEY)
    return cached if cached.present?

    if acquire_lock
      begin
        results = perform_all_checks
        Rails.cache.write(CACHE_KEY, results, expires_in: CACHE_TTL)
        results
      ensure
        release_lock
      end
    else
      # Another request is running checks; wait briefly then try cache
      sleep(0.1)
      Rails.cache.read(CACHE_KEY) || checking_status
    end
  end

  def acquire_lock
    Sidekiq.redis { |conn| conn.set(LOCK_KEY, "locked", nx: true, ex: LOCK_TTL) }
  end

  def release_lock
    Sidekiq.redis { |conn| conn.del(LOCK_KEY) }
  end

  def checking_status
    {
      postgresql: { status: :checking, latency: nil, error: nil },
      redis: { status: :checking, latency: nil, error: nil },
      minio: { status: :checking, latency: nil, error: nil },
      sidekiq: { status: :checking, latency: nil, error: nil, workers: 0, queues: 0, enqueued: 0 }
    }
  end

  def perform_all_checks
    {
      postgresql: check_postgresql,
      redis: check_redis,
      minio: check_minio,
      sidekiq: check_sidekiq
    }
  end

  def check_postgresql
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(CHECK_TIMEOUT) do
      ActiveRecord::Base.connection.execute("SELECT 1")
    end
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    { status: :healthy, latency: latency, error: nil }
  rescue => e
    Rails.logger.error("[SystemHealth] PostgreSQL check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message }
  end

  def check_redis
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(CHECK_TIMEOUT) do
      Sidekiq.redis { |conn| conn.ping }
    end
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    { status: :healthy, latency: latency, error: nil }
  rescue => e
    Rails.logger.error("[SystemHealth] Redis check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message }
  end

  def check_minio
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(CHECK_TIMEOUT) do
      ActiveStorage::Blob.service.exist?("health_check")
    end
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    { status: :healthy, latency: latency, error: nil }
  rescue => e
    Rails.logger.error("[SystemHealth] MinIO check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message }
  end

  def check_sidekiq
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    stats = Timeout.timeout(CHECK_TIMEOUT) do
      Sidekiq::Stats.new
    end
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    {
      status: :healthy,
      latency: latency,
      error: nil,
      workers: stats.workers_size,
      queues: stats.queues.size,
      enqueued: stats.enqueued
    }
  rescue => e
    Rails.logger.error("[SystemHealth] Sidekiq check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message, workers: 0, queues: 0, enqueued: 0 }
  end
end
