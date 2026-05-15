# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Structured JSON logging for Sidekiq background jobs (issue #652).
#
# Mirrors the lograge web-request format so log aggregators (ELK, Loki,
# Datadog, CloudWatch) can ingest both layers through the same pipeline.
# Sidekiq 8.x ships `Sidekiq::Logger::Formatters::JSON`, which emits
# single-line JSON for each job lifecycle event (start, done, error).
#
# Argument redaction policy: Sidekiq 8.x `JobLogger` never logs job arguments
# at any level — only the lifecycle markers (`start`, `done`, `fail`) plus the
# per-job context hash (`jid`, `class`, `logged_job_attributes`). Verified
# against sidekiq-8.1.5 `lib/sidekiq/job_logger.rb`. The `:info` level here is
# the standard production setting, not a redaction control. Application code
# that needs to log argument context must run arguments through
# `ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)`
# before writing — see `app/jobs/application_job.rb` for the canonical pattern.

Sidekiq.configure_server do |config|
  config.logger = Sidekiq::Logger.new($stdout, level: Logger::INFO)
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
end

# No client-side override: web processes enqueue jobs through Rails.logger /
# lograge already, so enqueue events surface through the HTTP request log line.
