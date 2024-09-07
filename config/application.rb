# frozen_string_literal: true

require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

# This is the main application configuration file for CipherSwarm.
module CipherSwarm
  # This is the main class for the CipherSwarm application.
  class Application < Rails::Application
    # Configure the path for configuration classes that should be used before initialization
    # NOTE: path should be relative to the project root (Rails.root)
    # config.anyway_config.autoload_static_config_path = "config/configs"
    #
    config.autoload_paths << Rails.root.join("app/components")
    config.view_component.preview_paths << Rails.root.join("app/components")
    config.load_defaults 7.2

    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "Eastern Time (US & Canada)"
    config.middleware.use Rack::Deflater
    config.active_job.queue_adapter = :sidekiq
  end
end
