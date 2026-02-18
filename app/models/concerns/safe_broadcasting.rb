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
  # - broadcast_replace_to: used by Campaign, Attack, Agent, HashItem
  # - broadcast_replace_later_to: used by Agent
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
