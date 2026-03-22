# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

source "https://rubygems.org"

ruby "3.4.5"

# Rails 8.1+ for modern real-time capabilities and performance improvements
gem "rails", "~> 8.1.2"

gem "bcrypt", "~> 3.1.22"
gem "bootsnap", "~> 1.23", require: false
gem "cssbundling-rails", "~> 1.4.3"
gem "image_processing", "~> 1.14"
gem "jbuilder", "~> 2.14.1"
gem "jsbundling-rails", "~> 1.3.1"
gem "pg", "~> 1.6.3"
gem "propshaft", "~> 1.3.1"
gem "puma", "~> 7.2"
gem "stimulus-rails", "~> 1.3.4"
gem "turbo-rails", "~> 2.0.23"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", ">= 8.0.4", require: false
  gem "bullet", "~> 8.1.0"
  gem "bundler-audit", "~> 0.9.3", require: false
  gem "capybara", "~> 3.40"
  gem "database_cleaner-active_record", "~> 2.2.2"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "erb_lint", "~> 0.9.0"
  gem "factory_bot_rails", "~> 6.5.1"
  gem "factory_trace", "~> 2.0.0"
  gem "faker", "~> 3.6.1"
  gem "fuubar", "~> 2.5.1"
  gem "rails-controller-testing", "~> 1.0.5"
  gem "rspec_junit_formatter", "~> 0.6", require: false
  gem "rspec-rails", "~> 8.0.4"
  gem "selenium-webdriver", "~> 4.41.0"
  gem "shoulda-callback-matchers", "~> 1.1.4"
  gem "shoulda-matchers", "~> 7.0.1"
  gem "simplecov", "~> 0.22", require: false
  gem "simplecov-lcov", "~> 0.9.0", require: false
  gem "undercover", "~> 0.8.4", require: false

  # Rubocop extensions
  gem "rswag-specs", github: "rswag/rswag", ref: "0a5a04983b5fe16f1698f2acf7ec787bf08ebf08", require: false
  gem "rubocop", "~> 1.85.1", require: false
  gem "rubocop-capybara", "~> 2.22.1", require: false
  gem "rubocop-factory_bot", "~> 2.28", require: false
  gem "rubocop-ordered_methods", "~> 0.14", require: false
  gem "rubocop-rails-omakase", "~> 1.1"
  gem "rubocop-rake", "~> 0.7.1", require: false
  gem "rubocop-rspec", "~> 3.9.0", require: false
  gem "rubocop-rspec_rails", "~> 2.32", require: false
  gem "rubocop-thread_safety", "~> 0.7.3", require: false
end

group :development do
  gem "annotaterb", "~> 4.22.0"
  gem "erb-formatter", "~> 0.7.3"
  gem "htmlbeautifier", "~> 1.4.3"
  gem "squasher", "~> 0.8", require: false
  gem "web-console", "~> 4.3.0"
end

gem "active_storage_validations", "~> 3.0.4"
gem "administrate", "~> 1.0"
gem "administrate-field-active_storage", "~> 1.0.6"
gem "administrate-field-jsonb", "~> 0.4.8"
gem "anyway_config", "~> 2.8.0"
gem "ar_lazy_preload", "~> 2.1.1"
gem "audited", "~> 5.8.0"
gem "aws-sdk-s3", "~> 1.216.0", groups: %i[production development]
gem "cancancan", "~> 3.6.1"
gem "csv", "~> 3.3.5" # Required for Ruby 3.4+ (no longer in standard library)
gem "devise", "~> 5.0.3"
gem "dry-initializer", "~> 3.2.0"
gem "inline_svg", "~> 1.10.0"

gem "lograge", "~> 0.14"
gem "meta-tags", "~> 2.22.3"
gem "oj", "~> 3.16.16"
gem "pagy", "~> 43.4.2"
gem "paranoia", "~> 3.1.0"
gem "redis", "~> 5.4.1"
gem "rexml", "~> 3.4.4"
gem "rolify", "~> 6.0.1"
# Use rswag v3 from GitHub to pick up Rails 8.1 gemspec support (merged upstream, unreleased gem).
# Pinned to specific commit SHA for reproducible builds. Update by checking rswag/rswag master.
gem "rswag", github: "rswag/rswag", ref: "0a5a04983b5fe16f1698f2acf7ec787bf08ebf08"
gem "show_for", "~> 0.9.0"
gem "sidekiq", "~> 8.1.1"
gem "sidekiq_alive", "~> 2.5.0", groups: %i[production development]
gem "sidekiq-cron", "~> 2.3.1"
gem "simple_form", "~> 5.4.1"
gem "state_machines-activerecord", "~> 0.100.0"
gem "store_model", "~> 4.5"
gem "sys-filesystem", "~> 1.5"
# Thruster removed — nginx handles HTTP/2, compression, and asset caching
# in production. Thruster's default 30s HTTP_READ_TIMEOUT silently killed
# large Active Storage direct uploads (multi-GB word lists). See #675.
gem "view_component", "~> 4.5.0"

gem "openssl", "~> 4.0.1"
