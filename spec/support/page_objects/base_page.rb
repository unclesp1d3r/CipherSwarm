# frozen_string_literal: true

# BasePage class provides common page interaction patterns for page objects
# All page objects should inherit from this class to gain access to common Capybara methods
class BasePage
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

  # Check if the page has content
  def has_content?(content, **options)
    @session.has_content?(content, **options)
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
end
