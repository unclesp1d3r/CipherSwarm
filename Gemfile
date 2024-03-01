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
  gem "rspec-rails", "~> 6.1.1"
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
gem "pundit", "~> 2.3"
gem "pagy", "~> 7.0"
gem "simple_form", "~> 5.3"
gem "inline_svg", "~> 1.9"
gem "show_for", "~> 0.8.1"

gem "erb_lint", "~> 0.5.0", groups: [ :development, :test ], require: false

gem "dockerfile-rails", ">= 1.6", group: :development
