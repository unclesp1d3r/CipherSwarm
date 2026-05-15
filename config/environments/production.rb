# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on local disk by default (works with shared volumes in Docker).
  # Set ACTIVE_STORAGE_SERVICE=s3 and AWS_* env vars to use S3-compatible storage
  # (AWS S3, MinIO, SeaweedFS, etc.).
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be disabled for local docker development via DISABLE_SSL=true
  config.assume_ssl = ENV["DISABLE_SSL"].blank?

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Can be disabled for local docker development via DISABLE_SSL=true
  config.force_ssl = ENV["DISABLE_SSL"].blank?

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger   = ActiveSupport::TaggedLogging.logger($stdout)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Suppress noisy framework loggers in production (issue #652).
  # - ActionMailer per-delivery lines are not useful for production
  #   observability; delivery failures still surface through the normal
  #   exception path and lograge's exception payload.
  # - ActionCable logs every Turbo Streams subscribe/unsubscribe, far higher
  #   volume than the operational signal value justifies.
  # Routed to IO::NULL rather than nil — some Rails 8 paths assume the logger
  # responds to #info/#debug, and a nil logger raises in those paths.
  config.action_mailer.logger = ActiveSupport::Logger.new(IO::NULL)
  config.action_cable.logger = ActiveSupport::Logger.new(IO::NULL)

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use Redis for caching. The connection pool keeps Rails.cache writes from
  # serializing through a single connection under high concurrent agent load —
  # the broadcast throttling feature (issue #568) adds per-Task-transition
  # cache writes, and `pool: false` would funnel those through one connection.
  # Size defaults to RAILS_MAX_THREADS (matches Puma's worker thread budget)
  # with a 1s acquisition timeout so a saturated pool fails fast rather than
  # stacking requests behind cache I/O.
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    pool: {
      size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
      timeout: 1
    }
  }

  # Use Sidekiq for background job processing
  config.active_job.queue_adapter = :sidekiq

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch("APPLICATION_HOST") }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # APPLICATION_HOST should be set to the hostname used to access the application
  # (e.g., "cipherswarm.lab.local"). When not set, host checking is disabled for
  # backward compatibility with existing deployments.
  if ENV["APPLICATION_HOST"].present?
    config.hosts = [
      ENV["APPLICATION_HOST"]
    ]
    # Skip DNS rebinding protection for health check endpoints.
    config.host_authorization = { exclude: ->(request) { request.path.start_with?("/up", "/api/v1/client/health") } }
  end
end
