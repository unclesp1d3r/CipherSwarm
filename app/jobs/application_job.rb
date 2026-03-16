# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Retry when temp storage is full — concurrent jobs may free space.
  # After 5 attempts, discard with a structured log message so operators
  # know to increase tmpfs size or reduce Sidekiq concurrency.
  retry_on InsufficientTempStorageError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.log_temp_storage_discard(error)
  end

  # Most jobs are safe to ignore if the underlying records are no longer available.
  # Log discarded jobs for visibility and debugging.
  discard_on ActiveJob::DeserializationError do |job, error|
    begin
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      safe_args = filter.filter(arguments: job.arguments)[:arguments]
      backtrace = error.backtrace&.first(5)&.join("\n           ") || "Not available"
      Rails.logger.warn(
        "[JobDiscarded] #{job.class.name} discarded due to DeserializationError. " \
        "Job ID: #{job.job_id}. Arguments: #{safe_args.inspect}. " \
        "Error: #{error.message}\n           Backtrace: #{backtrace}"
      )
    rescue StandardError
      # Avoid failing job execution due to logging errors
    end
  end

  # Logs a structured message when a job is discarded due to insufficient temp storage.
  # Extracted as a method so it can be tested independently (the retry_on block
  # is wrapped by ActiveJob machinery and cannot be invoked directly in tests).
  def log_temp_storage_discard(error)
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    safe_args = filter.filter(arguments: arguments)[:arguments]
    Rails.logger.error(
      "[TempStorage] #{self.class.name} discarded after retries — #{error.message}. " \
      "Job ID: #{job_id}. Arguments: #{safe_args.inspect}. " \
      "Action: increase tmpfs size or reduce Sidekiq concurrency. " \
      "See docs/deployment/docker-storage-and-tmp.md"
    )
  rescue StandardError => e
    Rails.logger.error("[TempStorage] Failed to log discard for #{self.class.name}: #{e.message}") rescue nil
  end
end
