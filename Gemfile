# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

source "https://rubygems.org"

ruby "3.4.5"

# Rails 8.0+ for modern real-time capabilities and performance improvements
gem "rails", "8.0.4"

gem "bcrypt"
gem "bootsnap", require: false
gem "cssbundling-rails"
gem "image_processing"
gem "jbuilder"
gem "jsbundling-rails"
gem "pg"
gem "propshaft"
gem "puma"
gem "solid_cable"
gem "solid_cache"
gem "stimulus-rails"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", require: false
  gem "bullet"
  gem "bundler-audit", require: false
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "erb_lint"
  gem "factory_bot_rails"
  gem "factory_trace"
  gem "faker"
  gem "fuubar"
  gem "rails-controller-testing"
  gem "rspec_junit_formatter", require: false
  gem "rspec-rails"
  gem "selenium-webdriver"
  gem "shoulda-callback-matchers"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  # Automatically downloads matching browser drivers for Selenium (Chromedriver)
  gem "webdrivers"

  # Rubocop extensions
  gem "rswag-specs", require: false
  gem "rubocop", require: false
  gem "rubocop-capybara", require: false
  gem "rubocop-factory_bot", require: false
  gem "rubocop-ordered_methods", require: false
  gem "rubocop-rails-omakase"
  gem "rubocop-rake", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
  gem "rubocop-thread_safety", require: false
end

group :development do
  gem "annotaterb"
  gem "dockerfile-rails"
  gem "erb-formatter"
  gem "htmlbeautifier"
  gem "squasher", require: false
  gem "web-console"
end

gem "active_storage_validations"
gem "administrate"
gem "administrate-field-active_storage"
# gem "administrate-field-enum" # Temporarily disabled - incompatible with Rails 8
gem "administrate-field-jsonb"
# gem "administrate-field-nested_has_many" # Temporarily disabled - incompatible with administrate 1.0
gem "anyway_config"
gem "ar_lazy_preload"
gem "audited"
gem "aws-sdk-s3", groups: %i[production development]
gem "cancancan"
gem "devise"
gem "dry-initializer"
gem "groupdate"
gem "inline_svg"
gem "kredis"
gem "maruku"
gem "meta-tags"
gem "oj"
gem "pagy", "~> 8.0"
gem "paranoia"
gem "redis"
gem "rexml"
gem "rolify"
gem "rswag"
gem "sem_version"
gem "show_for"
gem "sidekiq"
gem "sidekiq_alive", groups: %i[production development]
gem "sidekiq-cron"
gem "simple_form"
gem "state_machines-activerecord"
gem "store_model"
gem "thruster"
gem "view_component"
# gem "view_component-contrib", "~> 0.2.0"
