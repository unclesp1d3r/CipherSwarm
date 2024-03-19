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
# gem "redis", ">= 4.0.1"
# gem "kredis"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
# gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rubocop-rails-omakase", "~> 1.0"
  gem "brakeman", "~> 6.1", require: false
  gem "rspec-rails", "~> 6.1.2"
  gem "bullet"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
  # gem "spring"
  gem "annotate"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "devise", "~> 4.9"
gem "pagy", "~> 7.0"
gem "simple_form", "~> 5.3"
gem "inline_svg", "~> 1.9"
gem "show_for", "~> 0.8.1"

gem "erb_lint", "~> 0.5.0", groups: [ :development, :test ], require: false

gem "dockerfile-rails", ">= 1.6", group: :development

group :development, :test do
  gem "factory_bot_rails"
end

gem "factory_trace", "~> 1.1", groups: [ :development, :test ]

gem "faker", "~> 3.2", group: :test

gem "cancancan", "~> 3.5"

gem "sem_version", "~> 2.0"

gem "administrate", "~> 0.20.1"

gem "administrate-field-active_storage", "~> 1.0"

gem "administrate-field-jsonb", "~> 0.4.6"

gem "administrate-field-nested_has_many", "~> 1.3"

gem "administrate-field-enum", "~> 0.0.9"

gem "solid_queue", "~> 0.2.2"
