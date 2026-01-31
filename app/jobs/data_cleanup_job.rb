# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# DataCleanupJob handles periodic cleanup of old records.
#
# This job runs daily to:
# - Remove old agent error records beyond the configured retention period
# - Remove old audit records beyond the configured retention period
# - Archive old HashcatStatus records for completed tasks
#
# @example Scheduling (in config/schedule.yml)
#   data_cleanup_job:
#     cron: "0 3 * * *"  # Daily at 3 AM
#     class: "DataCleanupJob"
#     active_job: true
#
class DataCleanupJob < ApplicationJob
  queue_as :low

  # Performs the data cleanup operations.
  # Tracks failures and reports a summary at the end.
  #
  # @return [void]
  def perform
    @failures = []

    ActiveRecord::Base.connection_pool.with_connection do
      cleanup_old_agent_errors
      cleanup_old_audits
      cleanup_old_hashcat_statuses
    end

    report_cleanup_summary
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  private

  # Reports a summary of cleanup results, including any failures.
  #
  # @return [void]
  def report_cleanup_summary
    return if @failures.empty?

    Rails.logger.error(
      "[DataCleanup] Cleanup completed with #{@failures.size} failure(s): #{@failures.join(', ')}"
    )
  end

  # Removes agent errors older than the configured retention period.
  #
  # @return [void]
  def cleanup_old_agent_errors
    cutoff = ApplicationConfig.agent_error_retention.ago
    deleted_count = AgentError.where(created_at: ...cutoff).delete_all

    if deleted_count.positive?
      Rails.logger.info(
        "[DataCleanup] Deleted #{deleted_count} agent errors older than #{cutoff}"
      )
    end
  rescue StandardError => e
    @failures << :agent_errors
    log_cleanup_error("agent errors", e)
  end

  # Removes audit records older than the configured retention period.
  #
  # @return [void]
  def cleanup_old_audits
    cutoff = ApplicationConfig.audit_retention.ago
    deleted_count = Audited::Audit.where(created_at: ...cutoff).delete_all

    if deleted_count.positive?
      Rails.logger.info(
        "[DataCleanup] Deleted #{deleted_count} audit records older than #{cutoff}"
      )
    end
  rescue StandardError => e
    @failures << :audits
    log_cleanup_error("audits", e)
  end

  # Removes HashcatStatus records for completed tasks beyond retention period.
  #
  # @return [void]
  def cleanup_old_hashcat_statuses
    cutoff = ApplicationConfig.hashcat_status_retention.ago
    deleted_count = HashcatStatus
                    .joins(:task)
                    .where(tasks: { state: %w[completed exhausted failed] })
                    .where(hashcat_statuses: { created_at: ...cutoff })
                    .delete_all

    if deleted_count.positive?
      Rails.logger.info(
        "[DataCleanup] Deleted #{deleted_count} HashcatStatus records older than #{cutoff}"
      )
    end
  rescue StandardError => e
    @failures << :hashcat_statuses
    log_cleanup_error("HashcatStatus records", e)
  end

  # Logs a cleanup error with backtrace.
  #
  # @param resource_name [String] Name of the resource being cleaned
  # @param error [StandardError] The error that occurred
  # @return [void]
  def log_cleanup_error(resource_name, error)
    backtrace = error.backtrace&.first(5)&.join("\n           ") || "Not available"
    Rails.logger.error(
      "[DataCleanup] Error cleaning #{resource_name}: #{error.class} - #{error.message}\n" \
      "           Backtrace: #{backtrace}"
    )
  end
end
