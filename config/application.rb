# frozen_string_literal: true

require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module CipherSwarm
  class Application < Rails::Application
    config.load_defaults 7.1

    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "Eastern Time (US & Canada)"
    config.middleware.use Rack::Deflater
    config.active_job.queue_adapter = :sidekiq
  end
end
