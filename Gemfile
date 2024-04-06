source "https://rubygems.org"

ruby "3.2.2"

gem "rails", "~> 7.1.3", ">= 7.1.3.2"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"
gem "jbuilder"

gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rubocop-rails-omakase", "~> 1.0"
  gem "brakeman", "~> 6.1", require: false
  gem "rspec-rails", "~> 6.1.1"
  gem "bullet"
  gem "factory_bot_rails"
  gem "factory_trace", "~> 1.1"
  gem "erb_lint", "~> 0.5.0"
  gem "database_cleaner-active_record", "~> 2.1"

  # Rubocop extensions
  gem "rubocop-rspec", "~> 2.27", require: false
  gem "rubocop-factory_bot", "~> 2.25", require: false
  gem "rubocop-rake", "~> 0.6.0", require: false
  gem "rubocop-thread_safety", "~> 0.5.1", require: false
  gem "rswag-specs", "~> 2.13"
  gem "rubocop-ordered_methods", "~> 0.11"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
  # gem "spring"
  gem "annotate"
  gem "dockerfile-rails", ">= 1.6"
end

group :test do
  gem "selenium-webdriver"
  gem "faker", "~> 3.3"
  gem "simplecov", ">= 0.22.0", require: false
  gem "rspec_junit_formatter", require: false
  gem "shoulda-matchers", "~> 6.2"
end

gem "devise", "~> 4.9"
gem "pagy", "~> 8.0"
gem "simple_form", "~> 5.3"
gem "inline_svg", "~> 1.9"
gem "show_for", "~> 0.8.1"
gem "cancancan", "~> 3.5"
gem "sem_version", "~> 2.0"
gem "administrate", "~> 0.20.1"
gem "administrate-field-active_storage", "~> 1.0"
gem "administrate-field-jsonb", "~> 0.4.6"
gem "administrate-field-nested_has_many", "~> 1.3"
gem "administrate-field-enum", "~> 0.0.9"
gem "solid_queue", "~> 0.2.2"
gem "active_storage_validations", "~> 1.1"
gem "redis", "~> 5.1"
gem "kredis"
gem "audited", "~> 5.5"
gem "thruster", "~> 0.1.1"
gem "maruku", ">= 0.7.3"
gem "rack-timeout", ">= 0.6.3"
gem "rubocop", "~> 1.62", require: false
gem "shoulda-callback-matchers", "~> 1.1", group: :test

gem "rswag", "~> 2.13"

gem "state_machines-activerecord", "~> 0.9.0"

gem "positioning", "~> 0.2.0"
