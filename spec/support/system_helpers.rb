# frozen_string_literal: true

# SystemHelpers module provides common helper methods for system tests
# These helpers leverage Capybara, Devise, and FactoryBot for UI interactions
module SystemHelpers
  # Authentication Helpers

  # Sign in a user via the UI
  # @param user [User] the user to sign in
  # @param password [String] the user's password (default: "password")
  def sign_in_as(user, password: "password")
    visit new_user_session_path
    fill_in "Name", with: user.name
    fill_in "Password", with: password
    click_button "Log in"
    expect(page).to have_current_path(root_path)
  end

  # Sign out the current user via the UI
  def sign_out_via_ui
    find(".navbar .dropdown-toggle").click
    click_on "Log out"
    expect(page).to have_current_path(new_user_session_path)
  end

  # Create a user with FactoryBot and sign in via the UI
  # @param attributes [Hash] attributes to pass to the user factory
  # @param password [String] the user's password (default: "password")
  # @return [User] the created and signed-in user
  def create_and_sign_in_user(attributes = {}, password: "password")
    user = create(:user, attributes.merge(password: password, password_confirmation: password))
    sign_in_as(user, password: password)
    user
  end

  # Create an admin user with FactoryBot and sign in via the UI
  # @param attributes [Hash] attributes to pass to the admin factory
  # @param password [String] the admin's password (default: "password")
  # @return [User] the created and signed-in admin user
  def create_and_sign_in_admin(attributes = {}, password: "password")
    admin = create(:admin, attributes.merge(password: password, password_confirmation: password))
    sign_in_as(admin, password: password)
    admin
  end

  # Navigation Helpers

  # Navigate to the authenticated root (dashboard)
  def visit_dashboard
    visit root_path
  end

  # Navigate to the agents index page
  def visit_agents_page
    visit agents_path
  end

  # Navigate to the campaigns index page
  def visit_campaigns_page
    visit campaigns_path
  end

  # Navigate to the admin dashboard
  def visit_admin_dashboard
    visit admin_index_path
  end

  # Assertion Helpers

  # Assert that the page title or heading matches the expected text
  # @param page_title [String] the expected page title or heading
  def expect_to_be_on_page(page_title)
    expect(page).to have_css("h1", text: page_title)
  end

  # Assert that a flash message is present
  # @param message [String] the expected flash message text
  # @param type [Symbol] the flash message type (:notice, :alert, :info)
  def expect_flash_message(message, type: :notice)
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
    expect(page).to have_css(".alert.#{css_class}", text: message)
  end

  # Assert that a validation error is displayed
  # @param message [String] the expected validation error message
  def expect_validation_error(message)
    expect(page).to have_content(message)
  end

  # Form Helpers

  # Fill in a form with the given fields and submit it
  # @param fields_hash [Hash] a hash of field labels to values
  # @param button_text [String] the text of the submit button (default: "Submit")
  def fill_in_and_submit_form(fields_hash, button_text: "Submit")
    fields_hash.each do |label, value|
      fill_in label, with: value
    end
    click_button button_text
  end

  # Attach a file to a file input field and wait for upload completion
  # @param field [String] the label or ID of the file input field
  # @param file_path [String] the path to the file to attach
  def attach_file_and_wait(field, file_path)
    attach_file field, file_path
    # Wait for Active Storage direct upload to complete
    expect(page).to have_no_css(".direct-upload--pending", wait: 10)
  end
end
