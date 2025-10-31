# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "capybara/rspec"
require "selenium-webdriver"
require "fileutils"
require "pathname"

# Resolve project root without relying on Rails being loaded yet
PROJECT_ROOT = Pathname.new(File.expand_path("../..", __dir__))

# Register a Chrome driver that can run headless or headed based on ENV["HEADLESS"]
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  headless_env = ENV["HEADLESS"]
  headless = !(headless_env && headless_env.strip.downcase == "false")

  chrome_args = [
    "--disable-gpu",
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--window-size=1400,1400",
    "--disable-search-engine-choice-screen"
  ]
  chrome_args << "--headless=new" if headless
  chrome_args.each { |arg| options.add_argument(arg) }

  # Enable browser/driver logging for easier CI debugging
  # Use add_option for driver-specific options to support multiple selenium versions
  options.add_option("goog:loggingPrefs", {
    browser: "ALL",
    driver: "ALL"
  })

  # Configure default download behavior (useful for specs that involve downloads)
  download_dir = PROJECT_ROOT.join("tmp", "downloads").to_s
  begin
    FileUtils.mkdir_p(download_dir)
  rescue StandardError
    # noop if cannot create in some environments
  end
  options.add_preference("download.default_directory", download_dir)
  options.add_preference("download.prompt_for_download", false)
  options.add_preference("download.directory_upgrade", true)
  options.add_preference("safebrowsing.enabled", true)

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.configure do |config|
  # Use the registered driver for both default and JS-enabled tests
  config.default_driver = :headless_chrome
  config.javascript_driver = :headless_chrome

  # App server and timeouts
  config.server = :puma
  config.default_max_wait_time = 5
  config.automatic_label_click = true

  # Networking/URL behavior
  config.server_host = "127.0.0.1"

  # Artifacts (screenshots)
  config.save_path = PROJECT_ROOT.join("tmp", "capybara")
end

begin
  FileUtils.mkdir_p(Capybara.save_path)
rescue StandardError
  # noop if cannot create in some environments
end

# Capture a screenshot on failure for system specs
RSpec.configure do |config|
  config.after(:each, type: :system) do |example|
    next unless example.exception

    # Sanitize example description for filename
    name = example.full_description.gsub(%r{[^A-Za-z0-9_\- ]}, "").gsub(" ", "_")
  timestamp = Time.now.utc.strftime("%Y%m%d-%H%M%S")
    filename = "FAILURE_#{name}_#{timestamp}.png"

    path = File.join(Capybara.save_path.to_s, filename)
    begin
      Capybara.save_screenshot(path, full: true)
    rescue StandardError
      # Avoid raising within the test teardown
    end
  end
end
