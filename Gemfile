# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

source "https://rubygems.org"

ruby "3.4.5"

# Rails 8.0+ for modern real-time capabilities and performance improvements
gem "rails", "~> 8.0.4"

gem "bcrypt", "~> 3.1"
gem "bootsnap", "~> 1.18", require: false
gem "cssbundling-rails", "~> 1.4"
gem "image_processing", "~> 1.2"
gem "jbuilder", "~> 2.12"
gem "jsbundling-rails", "~> 1.3"
gem "pg", "~> 1.1"
gem "propshaft", "~> 1.1"
gem "puma", "~> 6.0"
gem "solid_cable", "~> 3.0"
gem "solid_cache", "~> 1.0"
gem "stimulus-rails", "~> 1.3"
gem "turbo-rails", "~> 2.0"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", "~> 7.1", require: false
  gem "bullet", "~> 8.0"
  gem "bundler-audit", "~> 0.9", require: false
  gem "capybara", "~> 3.40"
  gem "database_cleaner-active_record", "~> 2.1"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "erb_lint", "~> 0.5"
  gem "factory_bot_rails", "~> 6.4"
  gem "factory_trace", "~> 1.1"
  gem "faker", "~> 3.3"
  gem "fuubar", "~> 2.5"
  gem "rails-controller-testing", "~> 1.0"
  gem "rspec_junit_formatter", "~> 0.6", require: false
  gem "rspec-rails", "~> 6.1"
  gem "selenium-webdriver", "~> 4.19"
  gem "shoulda-callback-matchers", "~> 1.1"
  gem "shoulda-matchers", "~> 6.2"
  gem "simplecov", "~> 0.22", require: false

  # Rubocop extensions
  gem "rswag-specs", "~> 2.13", require: false
  gem "rubocop", "~> 1.82", require: false
  gem "rubocop-capybara", "~> 2.22", require: false
  gem "rubocop-factory_bot", "~> 2.28", require: false
  gem "rubocop-ordered_methods", "~> 0.14", require: false
  gem "rubocop-rails-omakase", "~> 1.1"
  gem "rubocop-rake", "~> 0.7", require: false
  gem "rubocop-rspec", "~> 3.8", require: false
  gem "rubocop-rspec_rails", "~> 2.32", require: false
  gem "rubocop-thread_safety", "~> 0.7", require: false
end

group :development do
  gem "annotaterb", "~> 4.11"
  gem "dockerfile-rails", "~> 1.6"
  gem "erb-formatter", "~> 0.7"
  gem "htmlbeautifier", "~> 1.4"
  gem "squasher", "~> 0.8", require: false
  gem "web-console", "~> 4.2"
end

gem "active_storage_validations", "~> 3.0"
gem "administrate", "~> 1.0"
gem "administrate-field-active_storage", "~> 1.0"
# gem "administrate-field-enum" # Temporarily disabled - incompatible with Rails 8
gem "administrate-field-jsonb", "~> 0.4"
# gem "administrate-field-nested_has_many" # Temporarily disabled - incompatible with administrate 1.0
gem "anyway_config", "~> 2.6"
gem "ar_lazy_preload", "~> 2.1"
gem "audited", "~> 5.5"
gem "aws-sdk-s3", "~> 1.151", groups: %i[production development]
gem "cancancan", "~> 3.5"
gem "devise", "~> 4.9"
gem "dry-initializer", "~> 3.1"
# gem "groupdate", "~> 6.4"  # REMOVED: Not currently used in codebase
gem "inline_svg", "~> 1.9"
gem "kredis", "~> 1.7"
gem "lograge", "~> 0.14"
# gem "maruku", "~> 0.7"  # REMOVED: Not used - consider commonmarker or redcarpet if markdown needed
gem "meta-tags", "~> 2.21"
gem "oj", "~> 3.16"
gem "pagy", "~> 8.0"
gem "paranoia", "~> 3.0"
gem "redis", "~> 5.1"
gem "rexml", "~> 3.3"
gem "rolify", "~> 6.0"
gem "rswag", "~> 2.13"
gem "sem_version", "~> 2.0"
gem "show_for", "~> 0.8"
gem "sidekiq", "~> 7.2"
gem "sidekiq_alive", "~> 2.4", groups: %i[production development]
gem "sidekiq-cron", "~> 1.12"
gem "simple_form", "~> 5.3"
gem "state_machines-activerecord", "~> 0.9"
gem "store_model", "~> 2.4"
gem "thruster", "~> 0.1"
gem "view_component", "~> 3.0"
# gem "view_component-contrib", "~> 0.2.0"
