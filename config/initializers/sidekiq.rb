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
# Argument redaction policy: Sidekiq logs job arguments only at the :debug
# level. The server log level here is :info, so arguments are not written by
# the Sidekiq logger itself. Jobs that need to log argument context must use
# `ActiveSupport::ParameterFilter` with
# `Rails.application.config.filter_parameters` — see `ApplicationJob` for the
# canonical pattern.

Sidekiq.configure_server do |config|
  config.logger = Sidekiq::Logger.new($stdout, level: Logger::INFO)
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
end

# No client-side override: web processes enqueue jobs through Rails.logger /
# lograge already, so enqueue events surface through the HTTP request log line.
