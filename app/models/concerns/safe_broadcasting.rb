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

  # Only wrap broadcast methods that are actually used in the codebase:
  # - broadcast_replace_to: used by Campaign (eta_summary), Attack
  # - broadcast_replace_later_to: used by Agent, Attack, Campaign (recent_cracks, via BroadcastRecentCracksJob), HashcatStatus
  # - broadcast_refresh_to/broadcast_refresh: used via broadcasts_refreshes
  BROADCAST_METHODS = %i[
    broadcast_replace_to
    broadcast_replace_later_to
    broadcast_refresh_to
    broadcast_refresh
  ].freeze

  # Errors that are expected during broadcast operations (connection/network issues).
  # Other StandardErrors may indicate bugs and should be surfaced in development.
  EXPECTED_BROADCAST_ERRORS = [
    IOError,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EPIPE
  ].freeze

  # Default leading-edge throttle window for `throttled_broadcast`. Tuned to
  # match the rate at which a human can usefully perceive UI changes for
  # continuous-value displays (attack progress, campaign ETA). Matches the
  # debounce window used by HashItem's trailing-edge broadcasts.
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

  # Leading-edge throttle for high-frequency broadcasts. Yields the block at
  # most once per `ttl` per `key`, using `Rails.cache.write(..., unless_exist:
  # true)` as an atomic distributed mutex (SET NX EX under Redis-backed
  # caches). When the cache layer itself fails, yields the block (fail-open):
  # we'd rather emit an occasional unthrottled broadcast than silently
  # suppress all UI updates during a Redis outage.
  #
  # Test-environment note: when `Rails.cache` is the null store (default in
  # test), every write returns `true`, so the helper always yields. The
  # downstream broadcast methods listed in BROADCAST_METHODS short-circuit
  # in test env on their own, so no actual broadcast is performed. Specs
  # that need to assert suppression should stub `Rails.cache.write`.
  #
  # @param key [String] throttle key — typically "<concept>_<record_id>"
  # @param ttl [ActiveSupport::Duration, Integer] throttle window
  # @yield the broadcast work to perform when the throttle fires
  # @return [Object, nil] block's return value when fired, nil when suppressed
  def throttled_broadcast(key, ttl: DEFAULT_THROTTLE_TTL)
    fired = begin
      Rails.cache.write(key, true, expires_in: ttl, unless_exist: true)
    rescue StandardError => e
      log_broadcast_error(e)
      true
    end

    yield if fired
  end

  # Logs broadcast errors with structured context
  #
  # @param error [StandardError] The error that occurred during broadcast
  def log_broadcast_error(error)
    model_name = self.class.name
    record_id = respond_to?(:id) ? id : "N/A"

    backtrace_lines = error.backtrace&.first(5)&.join("\n           ") || "Not available"

    Rails.logger.error(
      "[BroadcastError] Model: #{model_name} - Record ID: #{record_id} - Error: #{error.message}\n" \
      "Backtrace: #{backtrace_lines}"
    )
  end
end
