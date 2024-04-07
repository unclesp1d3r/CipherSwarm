# frozen_string_literal: true

require 'spec_helper'
require 'factory_bot'
require_relative 'support/database_cleaner'
require_relative 'support/controller_macros'
require_relative 'support/factory_bot'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require "view_component/test_helpers"
require "view_component/system_test_helpers"
require "capybara/rspec"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include FactoryBot::Syntax::Methods

  config.after(:all) do
    if Rails.env.test?
      FileUtils.rm_rf(Rails.root.join("tmp/storage"))
      FileUtils.mkdir_p(Rails.root.join("tmp/storage"))
      FileUtils.touch(Rails.root.join("tmp/storage/.keep"))
    end
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include ViewComponent::SystemTestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
