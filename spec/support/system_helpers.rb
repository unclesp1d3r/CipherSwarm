# frozen_string_literal: true

# SystemHelpers module provides common helper methods for system tests
# These helpers leverage Capybara, Devise, and FactoryBot for UI interactions
# rubocop:disable Metrics/ModuleLength -- Helper modules benefit from cohesion over arbitrary length limits
module SystemHelpers
  # Authentication Helpers

  # Sign in a user via the UI
  # @param user [User] the user to sign in
  # @param password [String] the user's password (default: "password")
  # @param name_field [String] the locator for the login identifier field
  # @param password_field [String] the locator for the password field
  def sign_in_as(user, password: "password", name_field: "Name", password_field: "Password")
    if respond_to?(:login_as) && Capybara.current_driver == :rack_test
      login_as(user, scope: :user)
      visit root_path
    else
      visit new_user_session_path
      expect(page).to have_field(name_field, wait: 5)
      if page.has_field?(name_field)
        fill_in name_field, with: user.name
      else
        fill_in "user_name", with: user.name
      end

      if page.has_field?(password_field)
        fill_in password_field, with: password
      else
        fill_in "user_password", with: password
      end
      click_button "Log in"
    end

    expect(page).to have_no_current_path(new_user_session_path, wait: 5)
    expect(page).to have_css("a.nav-link.dropdown-toggle", text: user.name, wait: 5)
  end

  # Sign out the current user via the UI
  # Sign out the current user via the UI. Optionally accept a user to scope
  # the dropdown toggle (useful when multiple dropdowns exist in the navbar).
  # @param user [User, nil]
  def sign_out_via_ui(user = nil)
    if user
      toggle = find("a.nav-link.dropdown-toggle", text: user.name)
    else
      # Prefer a dropdown toggle that is not the "Tools" menu (which may also
      # render a dropdown-toggle). Fall back to the first non-tools toggle.
      toggles = page.all("a.nav-link.dropdown-toggle")
      if toggles.empty?
        raise Capybara::ElementNotFound, "Could not find a user dropdown toggle to sign out via the UI. Ensure the user menu is present before calling sign_out_via_ui."
      end
      toggle = toggles.find { |el| el.text.strip.downcase != "tools" } || toggles.first
    end

    # Click the dropdown toggle and wait for dropdown to open
    toggle.click
    # Wait for the dropdown menu to appear
    sleep 0.2 # Brief pause for animation
    # Find the Log out button (button_to renders a submit button) and click it
    # Use execute_script to bypass visibility issues with Bootstrap dropdown
    logout_form = find("form[action*='sign_out']", visible: :all)
    page.execute_script("arguments[0].submit()", logout_form.native)
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

  # UI Interaction Helpers

  # Wait for a Bootstrap modal to be visible
  # @param modal_id [String] the ID of the modal
  # @param timeout [Integer] timeout in seconds (default: 5)
  def wait_for_modal(modal_id, timeout: 5)
    expect(page).to have_css("##{modal_id}.show", wait: timeout)
    expect(page).to have_css(".modal-backdrop.show", wait: timeout)
  end

  # Close a Bootstrap modal programmatically
  # @param modal_id [String] the ID of the modal
  def close_modal(modal_id)
    within("##{modal_id}") do
      if has_button?("Close")
        click_button "Close"
      elsif has_css?("button.btn-close")
        click_button(class: "btn-close")
      else
        # Fallback to escape key
        find(".modal-content").send_keys(:escape)
      end
    end
    expect(page).to have_no_css("##{modal_id}.show")
    expect(page).to have_no_css(".modal-backdrop.show")
  end

  # Expand a Bootstrap collapse section
  # @param section_id [String] ID of the collapsible element
  def expand_collapse_section(section_id)
    # Find the toggle button associated with this collapse
    toggle = find("button[data-bs-target='##{section_id}']")
    toggle.click
    expect(page).to have_css("##{section_id}.show")
  end

  # Verify ARIA label on element
  # @param selector [String] CSS selector for the element
  # @param expected_label [String] expected text of aria-label
  def verify_aria_label(selector, expected_label)
    expect(page).to have_css("#{selector}[aria-label='#{expected_label}']")
  end
end
# rubocop:enable Metrics/ModuleLength
