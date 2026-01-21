# frozen_string_literal: true

# BasePage class provides common page interaction patterns for page objects
# All page objects should inherit from this class to gain access to common Capybara methods
class BasePage
  include Rails.application.routes.url_helpers

  attr_reader :session

  # Initialize a new page object
  # @param session [Capybara::Session] the Capybara session (typically the `page` object)
  def initialize(session)
    @session = session
  end

  # Navigation Methods

  # Navigate to a specific path
  # @param path [String] the path to navigate to
  def visit_page(path)
    @session.visit(path)
  end

  # Get the current URL path
  # @return [String] the current path
  delegate :current_path, to: :session

  # Assertion Methods

  # Check if the page has a heading with the given text
  # @param text [String] the heading text to check for
  # @return [Boolean] true if the heading exists
  def has_heading?(text)
    @session.has_css?("h1", text: text)
  end

  # Check if the page has a flash message
  # @param message [String] the flash message text
  # @param type [Symbol] the flash message type (:notice, :alert, :info)
  # @return [Boolean] true if the flash message exists
  def has_flash_message?(message, type: :notice)
    css_class = case type
    when :notice
                  "alert-success"
    when :alert
                  "alert-danger"
    when :info
                  "alert-info"
    else
                  "alert"
    end
    @session.has_css?(".alert.#{css_class}", text: message)
  end

  # Interaction Methods

  # Click a button and wait for page load
  # @param button_text [String] the button text or ID
  def click_button_and_wait(button_text)
    @session.click_button(button_text)
  end

  # Fill in a form with the given fields
  # @param fields_hash [Hash] a hash of field labels to values
  def fill_form(fields_hash)
    fields_hash.each do |label, value|
      @session.fill_in(label, with: value)
    end
  end

  # Scope operations to a specific section
  # @param selector [String] the CSS selector for the section
  # @yield the block to execute within the section
  def within_section(selector, &)
    @session.within(selector, &)
  end

  # Scope operations within an element
  # @param element [Capybara::Node::Element, String] the element or selector
  # @yield the block to execute within the element
  def within(element, &)
    @session.within(element, &)
  end

  # Accept a browser confirmation dialog
  # @yield the block that triggers the confirmation
  def accept_confirm(&)
    @session.accept_confirm(&)
  end

  # Dismiss a browser confirmation dialog
  # @yield the block that triggers the confirmation
  def dismiss_confirm(&)
    @session.dismiss_confirm(&)
  end

  # Submit the primary form button
  # Prefers button[type='submit'] with btn-primary class, falls back to input[type='submit']
  # @return [BasePage] returns self for method chaining
  def submit_primary_form
    if has_selector?("button[type='submit'].btn-primary")
      click_button(nil, class: "btn-primary", match: :first)
    elsif has_selector?("button[type='submit']")
      click_button(nil, match: :first)
    else
      first("input[type='submit']")&.click
    end
    self
  end

  # Capybara Delegation
  # Delegate common Capybara methods to the session for convenience

  # Navigate to a path
  delegate :visit, to: :session

  # Click a link or button
  def click_on(*args)
    @session.click_on(*args)
  end

  # Click a link
  def click_link(*args)
    @session.click_link(*args)
  end

  # Click a button
  def click_button(*args)
    @session.click_button(*args)
  end

  # Fill in a form field
  def fill_in(locator, **options)
    @session.fill_in(locator, **options)
  end

  # Select from a dropdown
  def select(value, **options)
    @session.select(value, **options)
  end

  # Check a checkbox
  def check(*args)
    @session.check(*args)
  end

  # Uncheck a checkbox
  def uncheck(*args)
    @session.uncheck(*args)
  end

  # Choose a radio button
  def choose(*args)
    @session.choose(*args)
  end

  # Attach a file to a file input
  def attach_file(locator, path, **options)
    @session.attach_file(locator, path, **options)
  end

  # Find an element by selector
  def find(*args, **options)
    @session.find(*args, **options)
  end

  # Find all elements by selector
  def all(*args, **options)
    @session.all(*args, **options)
  end

  # Find first element by selector
  def first(*args, **options)
    @session.first(*args, **options)
  end

  # Check if the page has content
  def has_content?(content, **options)
    @session.has_content?(content, **options)
  end

  def has_text?(text, **options)
    @session.has_text?(text, **options)
  end

  def has_no_text?(text = nil, **options)
    @session.has_no_text?(text, **options)
  end

  # Check if the page has a CSS selector
  def has_css?(selector, **options)
    @session.has_css?(selector, **options)
  end

  # Check if the page has a form field (delegates to Capybara)
  def has_field?(locator, **options)
    @session.has_field?(locator, **options)
  end

  # Check if the page has a button (delegates to Capybara)
  def has_button?(locator, **options)
    @session.has_button?(locator, **options)
  end

  # Check if the page has a selector
  def has_selector?(selector, **options)
    @session.has_selector?(selector, **options)
  end

  # Check if a checkbox field is checked (delegates to Capybara)
  def has_checked_field?(locator, **options)
    @session.has_checked_field?(locator, **options)
  end

  # Check if a checkbox field is unchecked (delegates to Capybara)
  def has_unchecked_field?(locator, **options)
    @session.has_unchecked_field?(locator, **options)
  end

  # Turbo/Hotwire Helper Methods

  # Wait for Turbo to finish loading
  # This ensures no Turbo progress bar is visible before continuing
  # @param timeout [Integer] maximum time to wait in seconds (default: 5)
  # @return [Boolean] true if Turbo finished loading
  def wait_for_turbo(timeout: 5)
    @session.has_no_css?(".turbo-progress-bar", wait: timeout)
  end

  # Wait for Turbo Frame to load
  # @param frame_id [String] the ID of the turbo frame to wait for
  # @param timeout [Integer] maximum time to wait in seconds (default: 5)
  # @return [Boolean] true if frame finished loading
  def wait_for_turbo_frame(frame_id, timeout: 5)
    @session.has_no_css?("turbo-frame##{frame_id}[busy]", wait: timeout)
  end

  # Wait for all Turbo Frames on the page to finish loading
  # @param timeout [Integer] maximum time to wait in seconds (default: 5)
  # @return [Boolean] true if all frames finished loading
  def wait_for_all_turbo_frames(timeout: 5)
    @session.has_no_css?("turbo-frame[busy]", wait: timeout)
  end

  # Click and wait for Turbo to complete
  # Useful for links and buttons that trigger Turbo requests
  # @param locator [String] the element to click
  # @param kind [Symbol] the kind of element (:link, :button, or :on for generic)
  def click_and_wait_for_turbo(locator, kind: :on)
    case kind
    when :link
      @session.click_link(locator)
    when :button
      @session.click_button(locator)
    else
      @session.click_on(locator)
    end
    wait_for_turbo
  end

  # Submit form and wait for Turbo to complete
  # @param button_text [String, nil] optional button text to click (defaults to finding submit button)
  def submit_and_wait_for_turbo(button_text = nil)
    if button_text
      @session.click_button(button_text)
    else
      submit_primary_form
    end
    wait_for_turbo
  end

  # Wait for AJAX/fetch requests to complete
  # This uses a JavaScript check to ensure no active requests
  # @param timeout [Integer] maximum time to wait in seconds (default: 5)
  # @return [Boolean] true if no active requests
  def wait_for_ajax(timeout: 5)
    Timeout.timeout(timeout) do
      loop do
        active = @session.evaluate_script("typeof $ !== 'undefined' && $.active") rescue 0
        break if active.zero?

        sleep 0.1
      end
    end
    true
  rescue Timeout::Error
    false
  end

  # Wait for network to be idle (no pending requests)
  # More reliable than wait_for_ajax for modern apps
  # @param timeout [Integer] maximum time to wait in seconds (default: 5)
  def wait_for_network_idle(timeout: 5)
    Timeout.timeout(timeout) do
      loop do
        pending = @session.evaluate_script("window.performance.getEntriesByType('resource').filter(r => !r.responseEnd).length")
        break if pending.zero?

        sleep 0.1
      end
    end
    true
  rescue Timeout::Error
    false
  end
end
