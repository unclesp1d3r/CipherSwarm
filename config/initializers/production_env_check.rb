# frozen_string_literal: true

# Validates critical environment variables in production at boot time.
# Fails fast with clear error messages rather than cryptic runtime failures.
#
# Other critical variables are validated by their respective subsystems:
#   - RAILS_MASTER_KEY: Rails raises on boot if credentials cannot be decrypted
#   - POSTGRES_PASSWORD: PostgreSQL rejects connections with a clear auth error
#   - S3 credentials (when ACTIVE_STORAGE_SERVICE=s3): see storage_config_check.rb
Rails.application.config.after_initialize do
  next unless Rails.env.production?

  # Skip during asset precompilation — Redis/mailers aren't needed for asset builds.
  # CI runs `RAILS_ENV=production bin/rails assets:precompile` without Redis.
  next if defined?(Rake) && Rake.application.top_level_tasks.include?("assets:precompile")

  missing = []

  # APPLICATION_HOST is required for mailer URLs and Devise configuration.
  # Unlike RAILS_MASTER_KEY (which Rails validates) and POSTGRES_PASSWORD
  # (which PG validates), APPLICATION_HOST silently falls back to 'example.com'
  # in Devise and ApplicationMailer if not checked here.
  if ENV["APPLICATION_HOST"].blank?
    missing << "APPLICATION_HOST - Required for email URLs and redirects (e.g., cipherswarm.company.com)"
  end

  # REDIS_URL is required for Sidekiq (background jobs) and Action Cable (real-time).
  # Without it, both silently fall back to redis://localhost which fails in Docker.
  if ENV["REDIS_URL"].blank?
    missing << "REDIS_URL - Required for Sidekiq and Action Cable (e.g., redis://redis-db:6379/0)"
  end

  next if missing.empty?

  raise <<~MSG
    Required environment variables are missing in production:
      #{missing.join("\n  ")}

    Set these environment variables before starting the application.
    See docs/deployment/environment-variables.md for detailed documentation.
  MSG
end
