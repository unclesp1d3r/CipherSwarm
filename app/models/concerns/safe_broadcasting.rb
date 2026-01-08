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

  # List of Turbo broadcast methods to wrap with error handling
  BROADCAST_METHODS = %i[
    broadcast_remove_to
    broadcast_remove
    broadcast_replace_to
    broadcast_replace
    broadcast_update_to
    broadcast_update
    broadcast_before_to
    broadcast_after_to
    broadcast_append_to
    broadcast_append
    broadcast_prepend_to
    broadcast_prepend
    broadcast_refresh_to
    broadcast_refresh
    broadcast_action_to
    broadcast_action
    broadcast_replace_later_to
    broadcast_replace_later
    broadcast_update_later_to
    broadcast_update_later
    broadcast_append_later_to
    broadcast_append_later
    broadcast_prepend_later_to
    broadcast_prepend_later
    broadcast_refresh_later_to
    broadcast_refresh_later
    broadcast_action_later_to
    broadcast_action_later
    broadcast_render
    broadcast_render_to
    broadcast_render_later
    broadcast_render_later_to
  ].freeze

  included do
    # Override each broadcast method with a safe wrapper
    BROADCAST_METHODS.each do |method_name|
      define_method(method_name) do |*args, **kwargs, &block|
        super(*args, **kwargs, &block)
      rescue StandardError => e
        log_broadcast_error(e)
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
