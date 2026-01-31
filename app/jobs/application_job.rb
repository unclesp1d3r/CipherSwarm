# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available.
  # Log discarded jobs for visibility and debugging.
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn(
      "[JobDiscarded] #{job.class.name} discarded due to DeserializationError. " \
      "Job ID: #{job.job_id}. Arguments: #{job.arguments.inspect}. " \
      "Error: #{error.message}"
    )
  end
end
