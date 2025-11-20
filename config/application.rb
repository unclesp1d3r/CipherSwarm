# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# This is the main application configuration file for CipherSwarm.
module CipherSwarm
  # This is the main class for the CipherSwarm application.
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    # Autoload ViewComponent path
    # `config.autoload_paths` may be frozen in newer Rails versions, so avoid mutating it in-place.
    config.autoload_paths = config.autoload_paths + [Rails.root.join("app/components")]

    # Set time zone
    config.time_zone = "Eastern Time (US & Canada)"

    # Enable Gzip compression for responses
    config.middleware.use Rack::Deflater

    # Use Sidekiq for background jobs
    config.active_job.queue_adapter = :sidekiq
  end
end
