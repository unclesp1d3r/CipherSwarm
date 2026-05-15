# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Concern: SafeBroadcasting
#
# Provides safe broadcasting functionality for models that use Turbo Streams.
# Wraps broadcast operations in error handling to catch and log failures without disrupting
# application flow. This ensures that broadcast failures don't cause application errors
# and provide debugging information through structured logging.
#
# Usage:
#   include SafeBroadcasting
#   broadcasts_refreshes unless Rails.env.test?
#
# This concern overrides Turbo broadcast methods to add error handling around broadcast operations.
module SafeBroadcasting
  extend ActiveSupport::Concern

  # Wrap every Turbo broadcast entrypoint a model in this app might invoke:
  # - broadcast_replace_to: retained as a safety net; no active call sites since
  #   issue #568 migrated Attack#broadcast_attack_progress_update and
  #   Campaign#broadcast_eta_update to the async variant. Future callers
  #   that fall back to the synchronous form still get error handling.
  # - broadcast_replace_later_to: used by Agent, Attack, Campaign (eta_summary +
  #   recent_cracks via BroadcastRecentCracksJob), HashcatStatus
  # - broadcast_refresh_to/broadcast_refresh: used via broadcasts_refreshes
  BROADCAST_METHODS = %i[
    broadcast_replace_to
    broadcast_replace_later_to
    broadcast_refresh_to
    broadcast_refresh
  ].freeze

  # Errors that are expected during broadcast operations (connection/network issues).
  # Other StandardErrors may indicate bugs and should be surfaced in development.
  # Redis::BaseError covers cache-layer connection failures (CannotConnectError,
  # TimeoutError) when Rails.cache is Redis-backed.
  EXPECTED_BROADCAST_ERRORS = [
    IOError,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EPIPE,
    Redis::BaseError
  ].freeze

  # Namespace prefix for throttle keys. Keeps `throttled_broadcast` keys from
  # colliding with application-level Rails.cache entries (fragment caches,
  # counters, etc.) that share the Redis keyspace.
  THROTTLE_KEY_PREFIX = "throttle:broadcast"

  # Default leading-edge throttle window for `throttled_broadcast`. Tuned to
  # match the rate at which a human can usefully perceive UI changes for
  # continuous-value displays (attack progress, campaign ETA). Kept in lockstep
  # with HashItem::BROADCAST_DEBOUNCE_WINDOW so leading-edge and trailing-edge
  # callers cohabit the same window.
  DEFAULT_THROTTLE_TTL = 5.seconds

  included do
    BROADCAST_METHODS.each do |method_name|
      define_method(method_name) do |*args, **kwargs, &block|
        # Skip broadcasting in test environment to avoid performance overhead
        # The test cable adapter handles broadcasts silently, but skipping entirely is faster
        return nil if Rails.env.test?

        super(*args, **kwargs, &block)
      rescue *EXPECTED_BROADCAST_ERRORS => e
        # Expected connection errors - log and continue
        log_broadcast_error(e)
        nil
      rescue StandardError => e
        # Unexpected errors - log always, but re-raise in development to surface bugs
        log_broadcast_error(e)
        raise if Rails.env.development?
        nil
      end
    end
  end

  private

  # REASONING (per CONTRIBUTING.md):
  #   Why this extraction: high-frequency Turbo callbacks (Attack progress,
  #     Campaign ETA, see issue #568) saturate Puma workers rendering frames
  #     the client never sees. We needed a single primitive that wraps any
  #     broadcast in a leading-edge throttle so callers stay one-liners.
  #   Alternatives considered:
  #     - Rack/Sidekiq middleware: too far from the model layer; broadcasts
  #       fire from after_commit, not from a request.
  #     - Per-model debounce timers: duplicated state, not distributed across
  #       Puma processes.
  #     - rack-attack or a dedicated rate-limit gem: vendoring new deps for an
  #       8-line primitive violated the air-gapped constraint in AGENTS.md.
  #     - HashItem's trailing-edge debounce (Job.set(wait:).perform_later):
  #       wrong shape for continuous-value displays — the UI should update
  #       during a burst, not after.
  #   Decision rationale: SafeBroadcasting already owns the broadcast error
  #     posture and is included by every broadcaster, so the throttle lives
  #     here. Rails.cache.write(..., unless_exist: true) compiles to atomic
  #     SET NX EX under Redis; no new infra. Pair with broadcast_replace_later_to
  #     to keep render off the request path.
  #   Performance: one Redis SET NX EX per call (write-only, fast). Suppressed
  #     calls do not enqueue the downstream Sidekiq job, which is the actual
  #     savings.
  #
  # Leading-edge throttle for high-frequency broadcasts. Yields the block at
  # most once per `ttl` per `key`, using `Rails.cache.write(..., unless_exist:
  # true)` as an atomic distributed mutex (SET NX EX under Redis-backed
  # caches). The stored key is namespaced as
  # `<THROTTLE_KEY_PREFIX>:<caller-key>` so throttle entries cannot collide
  # with application-level Rails.cache writes.
  #
  # Fail-open posture (two distinct failure surfaces):
  #
  # 1. Cache-write fails (Redis unreachable, timeout): log the error and
  #    proceed with the block. An unthrottled frame is preferable to silently
  #    suppressing every UI update during an outage.
  #
  # 2. Block raises after the key was set: delete the key so the next caller
  #    is not silently suppressed for the rest of the TTL, then re-raise.
  #    Without this, a single bug in the yielded code (partial render, nil
  #    association) would cause a 5s blackout per record where the throttle
  #    appears to be active but no broadcast ever fired.
  #
  # Rescue posture mirrors the sibling BROADCAST_METHODS wrapper: connection-
  # class errors (EXPECTED_BROADCAST_ERRORS) fail open silently in any
  # environment; other StandardErrors fail open in production but re-raise
  # in development so bugs surface during a normal `bin/dev` run.
  #
  # Test-environment note: when `Rails.cache` is the null store (default in
  # test), every write returns `true`, so the helper always yields. The
  # downstream broadcast methods listed in BROADCAST_METHODS short-circuit
  # in test env on their own, so no actual broadcast is performed. Specs
  # that need to assert suppression should stub `Rails.cache.write`.
  #
  # @param key [String] caller-supplied throttle key — typically
  #   "<concept>_<record_id>". The stored Rails.cache key is automatically
  #   prefixed with THROTTLE_KEY_PREFIX.
  # @param ttl [ActiveSupport::Duration, Integer] throttle window
  # @yieldreturn [Object] the block's return value (passed through to the
  #   caller when the throttle fires)
  # @return [Object, nil] block's return value when fired, nil when suppressed
  def throttled_broadcast(key, ttl: DEFAULT_THROTTLE_TTL)
    namespaced_key = "#{THROTTLE_KEY_PREFIX}:#{key}"
    fired = cache_write_throttle(namespaced_key, ttl)
    return unless fired

    begin
      yield
    rescue StandardError
      cache_delete_throttle(namespaced_key)
      raise
    end
  end

  # Performs the atomic SET NX EX with the shared fail-open posture. Extracted
  # so `throttled_broadcast` reads as the two-phase contract (acquire-then-
  # yield) rather than a six-line begin/rescue at the top of the method.
  #
  # @return [Boolean] true when the throttle should fire (either the key was
  #   newly written, or the cache layer failed and we are failing open).
  def cache_write_throttle(namespaced_key, ttl)
    Rails.cache.write(namespaced_key, true, expires_in: ttl, unless_exist: true)
  rescue *EXPECTED_BROADCAST_ERRORS => e
    log_broadcast_error(e, context: "throttle:cache_write:#{namespaced_key}")
    true
  rescue StandardError => e
    log_broadcast_error(e, context: "throttle:cache_write:#{namespaced_key}")
    raise if Rails.env.development?
    true
  end

  # Best-effort key release for the throttle-block-raised path. Swallowed
  # failures here are non-fatal: the worst case is the original 5s
  # leading-edge window stays held, matching the pre-namespaced-cleanup
  # behavior. The block exception is the signal the caller should act on,
  # not a follow-on cache delete error.
  def cache_delete_throttle(namespaced_key)
    Rails.cache.delete(namespaced_key)
  rescue StandardError => e
    log_broadcast_error(e, context: "throttle:cache_delete:#{namespaced_key}")
  end

  # Logs broadcast errors with structured context.
  #
  # @param error [StandardError] the error that occurred during broadcast
  # @param context [String, nil] optional phase tag distinguishing where in
  #   the broadcast flow the error originated (e.g. "throttle:cache_write:..."
  #   vs the default unannotated broadcast-method-wrapper path). Surfacing
  #   the phase lets operators tell a cache-mutex outage from a Sidekiq-enqueue
  #   failure in log scraping without grepping line numbers.
  def log_broadcast_error(error, context: nil)
    model_name = self.class.name
    record_id = respond_to?(:id) ? id : "N/A"
    context_tag = context.present? ? " - Context: #{context}" : ""

    backtrace_lines = error.backtrace&.first(5)&.join("\n           ") || "Not available"

    Rails.logger.error(
      "[BroadcastError] Model: #{model_name} - Record ID: #{record_id}#{context_tag} - Error: #{error.message}\n" \
      "Backtrace: #{backtrace_lines}"
    )
  end
end
