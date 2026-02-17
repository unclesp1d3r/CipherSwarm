# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Performs health checks against core infrastructure services and caches results.
#
# Checks PostgreSQL, Redis, MinIO (ActiveStorage), and Sidekiq. Results are
# cached for 1 minute with a Redis-based lock to prevent cache stampede when
# multiple requests arrive simultaneously.
#
# The lock uses unique tokens with a Lua CAS script for safe release,
# preventing accidental release of a lock acquired by another request
# after timeout.
#
# REASONING:
# - Why: SystemHealthController contained 138 lines of business logic (health checks,
#   caching, locking). Extracting to a service follows the project's existing service
#   object pattern (TaskAssignmentService, etc.) and keeps the controller thin.
# - Alternatives considered:
#   - Health check gem (e.g., health_check): adds external dependency for simple checks
#   - Background job + cache-only controller: more complex, health data could be stale
#   - Separate service per check: over-engineering for 4 simple checks
# - Decision: Single service class with cache-stampede prevention via Redis lock.
# - Performance: Checks cached for 1 minute. Lock prevents thundering herd.
#   When lock is contended, returns cached data or :checking status immediately
#   (no thread-blocking sleep).
class SystemHealthCheckService
  CACHE_KEY = "system_health_checks"
  CACHE_TTL = 1.minute
  CHECK_TIMEOUT = 5 # seconds
  LOCK_KEY = "system_health_check_lock"
  LOCK_TTL = 10 # seconds

  # Lua script for atomic compare-and-delete lock release.
  # Only deletes the lock if it still holds our token, preventing
  # accidental release of a lock acquired by another request after expiry.
  RELEASE_LOCK_SCRIPT = <<~LUA
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end
  LUA

  def self.call
    new.call
  end

  def call
    cached = Rails.cache.read(CACHE_KEY)
    return cached if cached.present?

    lock_token = SecureRandom.hex(16)
    lock_acquired = nil
    lock_error = nil
    begin
      lock_acquired = acquire_lock(lock_token)
    rescue StandardError => e
      lock_error = e
      Rails.logger.error("[SystemHealth] Lock acquisition failed: #{e.message}")
    end

    if lock_acquired
      begin
        results = perform_all_checks
        Rails.cache.write(CACHE_KEY, results, expires_in: CACHE_TTL)
        results
      ensure
        begin
          release_lock(lock_token)
        rescue StandardError => e
          Rails.logger.error("[SystemHealth] Lock release failed: #{e.message}")
        end
      end
    elsif lock_error
      # Redis is down — still run non-Redis checks, skip caching
      {
        postgresql: check_postgresql,
        redis: {
          status: :unhealthy,
          latency: nil,
          error: lock_error.message,
          used_memory: nil,
          connected_clients: nil,
          hit_rate: nil
        },
        minio: check_minio,
        sidekiq: check_sidekiq,
        application: application_info,
        checked_at: Time.current.iso8601
      }
    else
      # Lock contention — another request is performing checks
      checking_status
    end
  end

  private

  def acquire_lock(token)
    Sidekiq.redis { |conn| conn.set(LOCK_KEY, token, nx: true, ex: LOCK_TTL) }
  end

  def check_minio
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(CHECK_TIMEOUT) do
      ActiveStorage::Blob.service.exist?("health_check")
    end
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

    storage_used = nil
    bucket_count = nil
    begin
      storage_used = ActiveStorage::Blob.sum(:byte_size)
      bucket_count = ActiveStorage::Blob.service.respond_to?(:buckets) ? ActiveStorage::Blob.service.buckets.count : nil
    rescue => e
      Rails.logger.warn("[SystemHealth] MinIO extended metrics failed: #{e.message}")
    end

    { status: :healthy, latency: latency, error: nil, storage_used: storage_used, bucket_count: bucket_count }
  rescue => e
    Rails.logger.error("[SystemHealth] MinIO check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message, storage_used: nil, bucket_count: nil }
  end

  def check_postgresql
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(CHECK_TIMEOUT) do
      ActiveRecord::Base.connection.execute("SELECT 1")
    end
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

    connection_count = nil
    database_size = nil
    begin
      result = ActiveRecord::Base.connection.execute(
        "SELECT numbackends FROM pg_stat_database WHERE datname = current_database()"
      )
      connection_count = result.first&.fetch("numbackends", nil)

      result = ActiveRecord::Base.connection.execute(
        "SELECT pg_database_size(current_database()) AS size"
      )
      database_size = result.first&.fetch("size", nil)&.to_i
    rescue => e
      Rails.logger.warn("[SystemHealth] PostgreSQL extended metrics failed: #{e.message}")
    end

    { status: :healthy, latency: latency, error: nil, connection_count: connection_count, database_size: database_size }
  rescue => e
    Rails.logger.error("[SystemHealth] PostgreSQL check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message, connection_count: nil, database_size: nil }
  end

  def check_redis
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    info = Timeout.timeout(CHECK_TIMEOUT) do
      Sidekiq.redis { |conn| conn.info }
    end
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

    used_memory = info["used_memory_human"]
    connected_clients = info["connected_clients"]&.to_i
    hits = info["keyspace_hits"]&.to_i || 0
    misses = info["keyspace_misses"]&.to_i || 0
    hit_rate = (hits + misses).positive? ? ((hits.to_f / (hits + misses)) * 100).round(2) : nil

    {
      status: :healthy, latency: latency, error: nil,
      used_memory: used_memory, connected_clients: connected_clients, hit_rate: hit_rate
    }
  rescue => e
    Rails.logger.error("[SystemHealth] Redis check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message, used_memory: nil, connected_clients: nil, hit_rate: nil }
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

  def application_info
    sidekiq_processes = begin
      Sidekiq::ProcessSet.new.size
    rescue => e
      Rails.logger.warn("[SystemHealth] Sidekiq process check failed: #{e.message}")
      0
    end

    {
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION,
      uptime: format_uptime,
      workers_running: sidekiq_processes.positive?,
      worker_count: sidekiq_processes
    }
  end

  def checking_status
    {
      postgresql: { status: :checking, latency: nil, error: nil, connection_count: nil, database_size: nil },
      redis: { status: :checking, latency: nil, error: nil, used_memory: nil, connected_clients: nil, hit_rate: nil },
      minio: { status: :checking, latency: nil, error: nil, storage_used: nil, bucket_count: nil },
      sidekiq: { status: :checking, latency: nil, error: nil, workers: 0, queues: 0, enqueued: 0 },
      application: application_info,
      checked_at: Time.current.iso8601
    }
  end

  def format_uptime
    booted_at = Rails.application.config.respond_to?(:booted_at) ? Rails.application.config.booted_at : nil
    return "unknown" unless booted_at

    seconds = (Time.current - booted_at).to_i
    days = seconds / 86400
    hours = (seconds % 86400) / 3600
    minutes = (seconds % 3600) / 60

    parts = []
    parts << "#{days}d" if days.positive?
    parts << "#{hours}h" if hours.positive?
    parts << "#{minutes}m" if minutes.positive?
    parts.empty? ? "< 1m" : parts.join(" ")
  end

  def perform_all_checks
    checks = { postgresql: :check_postgresql, redis: :check_redis, minio: :check_minio, sidekiq: :check_sidekiq }
    results = checks.transform_values { |m| send(m) }
    results[:application] = application_info
    results[:checked_at] = Time.current.iso8601
    results
  end

  def release_lock(token)
    Sidekiq.redis do |conn|
      conn.call("EVAL", RELEASE_LOCK_SCRIPT, 1, LOCK_KEY, token)
    end
  end
end
