# frozen_string_literal: true

# Page object for the Devise sign-in page
class SignInPage < BasePage
  # Visit the sign in page
  def visit_page
    visit Rails.application.routes.url_helpers.new_user_session_path
    self
  end

  # Fill and submit the sign in form
  # @param name [String]
  # @param password [String]
  def sign_in_with(name:, password:)
    # Ensure we fill and submit the form itself to avoid issues when Turbo/Turbo Stream responses are used by Devise or the application layout.
    within("form") do
      fill_in "Name", with: name
      fill_in "Password", with: password
      click_button "Log in"
    end
    self
  end

  # Attempt sign in with clearly invalid credentials
  def sign_in_with_invalid_credentials
    sign_in_with(name: "invalid", password: "wrong")
  end

  # Returns true if the sign in form is present on the page
  def has_sign_in_form?
    # Check for presence of Name and Password fields and the Log in button
    has_field?("Name") && has_field?("Password", type: "password") && has_button?("Log in")
  end

  # Check for an error flash (alert-danger). If message provided, assert text.
  # @param message [String, nil]
  def has_error_message?(message = nil)
    if message
      has_css?(".alert.alert-danger", text: message)
    else
      has_css?(".alert.alert-danger")
    end
  end

  # Specific invalid credentials message (Devise i18n uses %{authentication_keys})
  def has_invalid_credentials_error?
    # Use Devise i18n key to avoid brittle hard-coded English strings.
    # Devise 5 applies downcase_first to humanized authentication keys.
    has_error_message?(I18n.t("devise.failure.invalid", authentication_keys: devise_auth_keys_label))
  end

  # Locked account error message
  def has_locked_account_error?
    # Devise hides the locked reason when paranoid mode is enabled, so fall back to
    # the generic invalid credentials flash in that scenario.
    expected_message = if Devise.paranoid
      I18n.t("devise.failure.invalid", authentication_keys: devise_auth_keys_label)
    else
      I18n.t("devise.failure.locked")
    end

    has_error_message?(expected_message)
  end

  # Click the "Forgot your password?" link
  def click_forgot_password
    click_link "Forgot your password?"
    self
  end

  # Check the "Remember me" checkbox
  def check_remember_me
    check "Remember me"
    self
  end

  private

  # Replicate Devise 5's downcase_first behavior for authentication key labels.
  def devise_auth_keys_label
    Devise.authentication_keys.map { |key|
      User.human_attribute_name(key).downcase_first
    }.join(I18n.t(:"support.array.words_connector"))
  end
end
