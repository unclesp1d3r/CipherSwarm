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
    if acquire_lock(lock_token)
      begin
        results = perform_all_checks
        Rails.cache.write(CACHE_KEY, results, expires_in: CACHE_TTL)
        results
      ensure
        release_lock(lock_token)
      end
    else
      Rails.cache.read(CACHE_KEY) || checking_status
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
    { status: :healthy, latency: latency, error: nil }
  rescue => e
    Rails.logger.error("[SystemHealth] MinIO check failed: #{e.message}")
    { status: :unhealthy, latency: nil, error: e.message }
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

  def checking_status
    {
      postgresql: { status: :checking, latency: nil, error: nil },
      redis: { status: :checking, latency: nil, error: nil },
      minio: { status: :checking, latency: nil, error: nil },
      sidekiq: { status: :checking, latency: nil, error: nil, workers: 0, queues: 0, enqueued: 0 }
    }
  end

  def perform_all_checks
    checks = { postgresql: :check_postgresql, redis: :check_redis, minio: :check_minio, sidekiq: :check_sidekiq }
    checks.transform_values { |m| send(m) }
  end

  def release_lock(token)
    Sidekiq.redis do |conn|
      conn.call("EVAL", RELEASE_LOCK_SCRIPT, 1, LOCK_KEY, token)
    end
  end
end
