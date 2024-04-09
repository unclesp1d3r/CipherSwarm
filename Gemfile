# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.2.2"

gem "cssbundling-rails"
gem "importmap-rails"
gem "jbuilder"
gem "pg", ">= 1.1"
gem "puma", ">= 5.0"

# Restricting the version of Rails to avoid breaking changes
gem "rails", "~> 7.1.3", ">= 7.1.3.2"
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"

gem "bcrypt", ">= 3.1.7"
gem "bootsnap", require: false
gem "image_processing", ">= 1.2"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", ">= 6.1", require: false
  gem "bullet"
  gem "database_cleaner-active_record", ">= 2.1"
  gem "debug", platforms: %i[mri windows]
  gem "erb_lint", ">= 0.5.0"
  gem "factory_bot_rails"
  gem "factory_trace", ">= 1.1"
  gem "rspec-rails", ">= 6.1.1"
  gem "rubocop-rails-omakase", ">= 1.0"

  # Rubocop extensions
  gem "rswag-specs", ">= 2.13"
  gem "rubocop-factory_bot", ">= 2.25", require: false
  gem "rubocop-ordered_methods", ">= 0.11"
  gem "rubocop-rake", ">= 0.6.0", require: false
  gem "rubocop-rspec", ">= 2.27", require: false
  gem "rubocop-thread_safety", ">= 0.5.1", require: false
end

group :development do
  gem "rack-mini-profiler"
  gem "web-console"
  # gem "spring"
  gem "annotate"
  gem "dockerfile-rails", ">= 1.6"
end

group :test do
  gem "capybara", ">= 3.40"
  gem "faker", ">= 3.3"
  gem "rspec_junit_formatter", require: false
  gem "selenium-webdriver"
  gem "shoulda-matchers", ">= 6.2"
  gem "simplecov", ">= 0.22.0", require: false
end

gem "active_storage_validations", ">= 1.1"
gem "administrate", ">= 0.20.1"
gem "administrate-field-active_storage", ">= 1.0"
gem "administrate-field-enum", ">= 0.0.9"
gem "administrate-field-jsonb", ">= 0.4.6"
gem "administrate-field-nested_has_many", ">= 1.3"
gem "audited", ">= 5.5"
gem "cancancan", ">= 3.5"
gem "devise", ">= 4.9"
gem "inline_svg", ">= 1.9"
gem "kredis"
gem "maruku", ">= 0.7.3"
gem "pagy", ">= 8.0"
gem "rack-timeout", ">= 0.6.3"
gem "redis", ">= 5.1"

# Restricting the version of the gem to avoid breaking changes
gem "rubocop", "~> 1.62", require: false
gem "sem_version", ">= 2.0"
gem "shoulda-callback-matchers", ">= 1.1", group: :test
gem "show_for", ">= 0.8.1"
gem "simple_form", ">= 5.3"
gem "solid_queue", ">= 0.2.2"
gem "thruster", ">= 0.1.1"

gem "rswag", ">= 2.13"

gem "state_machines-activerecord", ">= 0.9.0"

gem "positioning", ">= 0.2.0"

gem "view_component", ">= 3.11"

gem "htmlbeautifier", "~> 1.4", :group => :development

gem "haml-rails", "~> 2.1"
