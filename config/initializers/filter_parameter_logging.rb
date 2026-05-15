# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate,
  :otp, :ssn, :cvv, :cvc, :plain_text, :hash_value,
  # Anchored regex: redact ONLY the literal `hash` key (the v1 Agent API
  # `submit_crack` wire field at `app/controllers/api/v1/client/tasks_controller.rb`),
  # without matching `hash_list_id`, `hash_value`, `hash_type`, `password_hash`,
  # or any other substring. `ActiveSupport::ParameterFilter` accepts Regexp
  # entries and applies them via `Regexp#match?`.
  /\Ahash\z/i
]
