# frozen_string_literal: true

# Validates that required S3 credentials are present when S3 storage is active.
# Fails fast at boot rather than at the first upload/download attempt.
Rails.application.config.after_initialize do
  next unless Rails.application.config.active_storage.service == :s3

  missing = %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY].select { |key| ENV[key].blank? }
  next if missing.empty?

  raise <<~MSG
    S3 storage is active (ACTIVE_STORAGE_SERVICE=s3) but required credentials are missing:
      #{missing.join(', ')}
    Set these environment variables or switch to local storage (ACTIVE_STORAGE_SERVICE=local).
  MSG
end
