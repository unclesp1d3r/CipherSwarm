# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User Sign In" do
  let(:sign_in_page) { SignInPage.new(page) }
  let(:user) { create(:user) }

  before do
    ActionMailer::Base.deliveries.clear
  end

  it "allows a user to sign in with valid credentials" do
    sign_in_page
      .visit_page
      .sign_in_with(name: user.name, password: "password")

    # Wait a little for redirects/Turbo to settle
    expect(page).to have_current_path(root_path, wait: 5)
    expect(page).to have_css("h1", text: "Dashboard")
    expect_flash_message(I18n.t("devise.sessions.signed_in"), type: :notice)
    expect(page).to have_content(user.name)
  end

  it "shows error message with invalid credentials" do
    sign_in_page.visit_page
                 .sign_in_with(name: user.name, password: "wrongpassword")

    # Remains on sign in page
    expect(page).to have_current_path(user_session_path)
    expect(sign_in_page).to have_invalid_credentials_error
    expect(sign_in_page).to have_sign_in_form
  end

  it "shows error message for non-existent user" do
    sign_in_page.visit_page
                 .sign_in_with(name: "nonexistent", password: "password")

    expect_flash_message(I18n.t("devise.failure.invalid", authentication_keys: "Name"), type: :alert)
  end

  it "prevents sign-in and shows locked account message" do
    user.lock_access!

    sign_in_page.visit_page
                 .sign_in_with(name: user.name, password: "password")

    expect(sign_in_page).to have_locked_account_error
    expect(page).to have_current_path(user_session_path)
  end

  it "allows user to sign in and then sign out" do
    # Use SystemHelpers sign_in_as if available; otherwise use page object
    if respond_to?(:sign_in_as)
      sign_in_as(user)
    else
      sign_in_page.visit_page.sign_in_with(name: user.name, password: "password")
    end

    expect(page).to have_current_path(root_path)

    # open user dropdown tied to this user and log out
    find("a.nav-link.dropdown-toggle", text: user.name).click
    click_on "Log out"

    expect(page).to have_current_path(new_user_session_path)
    expect_flash_message(I18n.t("devise.sessions.signed_out"), type: :notice)

    # ensure dashboard requires authentication
    visit root_path
    expect(page).to have_current_path(new_user_session_path)
  end

  it "allows user to check remember me option" do
    sign_in_page.visit_page
    sign_in_page.check_remember_me
    sign_in_page.sign_in_with(name: user.name, password: "password")

    expect(page).to have_current_path(root_path)
    expect_flash_message(I18n.t("devise.sessions.signed_in"), type: :notice)
  end

  it "navigates to password reset page when clicking forgot password" do
    sign_in_page.visit_page
    sign_in_page.click_forgot_password

    expect(page).to have_current_path(new_user_password_path)
    expect(page).to have_css("h2", text: "Forgot your password?")
  end
end
