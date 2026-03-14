# frozen_string_literal: true

# Validates that required environment variables are present in production.
# Fails fast at boot with clear error messages rather than at runtime.
Rails.application.config.after_initialize do
  next unless Rails.env.production?

  missing = []

  # APPLICATION_HOST is required for mailer URLs and Devise configuration
  if ENV["APPLICATION_HOST"].blank?
    missing << "APPLICATION_HOST - Required for email URLs and redirects (e.g., cipherswarm.company.com)"
  end

  next if missing.empty?

  raise <<~MSG
    Required environment variables are missing in production:
      #{missing.join("\n  ")}

    Set these environment variables before starting the application.
    See docs/deployment/environment-variables.md for detailed documentation.
  MSG
end
