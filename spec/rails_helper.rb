# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "spec_helper"
require "factory_bot"
require_relative "support/database_cleaner"
require_relative "support/capybara"
require_relative "support/controller_macros"
require_relative "support/factory_bot"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require_relative "support/system_helpers"
require_relative "support/page_objects/base_page"
require "capybara/rspec"
require "view_component/test_helpers"
require "view_component/test_helpers"
require "view_component/system_test_helpers"
require "capybara/rspec"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :view_component
  config.include Capybara::RSpecMatchers, type: :view_component

  config.define_derived_metadata(file_path: %r{/spec/components}) do |metadata|
    metadata[:type] = :view_component
  end

  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include FactoryBot::Syntax::Methods
  config.include ActionDispatch::TestProcess
  config.include SystemHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Tag everything under spec/system as type: :system
  config.define_derived_metadata(file_path: %r{/spec/system}) do |metadata|
    metadata[:type] = :system
  end

  # Use the Capybara Selenium Chrome driver for system tests
  config.before(:each, type: :system) do
    driven_by :headless_chrome
  end

  # Configure Warden test mode for Devise
  config.before(:suite) do
    Warden.test_mode!
    # Ensure Devise mappings are loaded
    Rails.application.reload_routes!
  end

  config.after do
    Warden.test_reset!
  end

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
  config.include ViewComponent::TestHelpers, type: :view_component
  config.include Capybara::RSpecMatchers, type: :view_component

  config.define_derived_metadata(file_path: %r{/spec/components}) do |metadata|
    metadata[:type] = :view_component
  end

  config.include ViewComponent::TestHelpers, type: :component
  config.include ViewComponent::SystemTestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
