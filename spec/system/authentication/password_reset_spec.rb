# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Password Reset" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  before do
    ActionMailer::Base.deliveries.clear
  end

  def extract_reset_token_from_email
    email = ActionMailer::Base.deliveries.last
    return unless email
    body = email.body.to_s
    match = body.match(/reset_password_token=([^"'&\s]+)/)
    match && match[1]
  end

  def request_password_reset_for(user)
    visit new_user_password_path
    fill_in "Email", with: user.email

    deliveries_before = ActionMailer::Base.deliveries.count
    click_button "Send me reset password instructions"

    timeout = Capybara.default_max_wait_time
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    loop do
      break if ActionMailer::Base.deliveries.count >= deliveries_before + 1
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time > timeout
        raise RSpec::Expectations::ExpectationNotMetError, "Timed out waiting for reset email"
      end
      sleep 0.05
    end

    extract_reset_token_from_email
  end

  def complete_password_reset(token, new_password)
    visit edit_user_password_path(reset_password_token: token)
    fill_in "New password", with: new_password
    fill_in "Confirm your new password", with: new_password
    click_button "Change my password"
  end

  def expect_successful_password_reset
    expect_flash_message("Your password has been changed successfully. You are now signed in.", type: :notice)
    expect(page).to have_current_path(root_path)
    expect(page).to have_css("h1", text: "Dashboard")
  end

  def sign_out_through_ui(user)
    if respond_to?(:sign_out_via_ui)
      sign_out_via_ui(user)
    else
      find("a.nav-link.dropdown-toggle", text: user.name).click
      click_on "Log out"
    end
  end

  def sign_in_through_ui(name:, password:)
    visit new_user_session_path
    fill_in "Name", with: name
    fill_in "Password", with: password
    click_button "Log in"
  end

  it "sends password reset email when valid email is provided" do
    visit new_user_session_path
    click_link "Forgot your password?"

    expect(page).to have_current_path(new_user_password_path)
    expect(page).to have_css("h2", text: "Forgot your password?")

    fill_in "Email", with: user.email
    click_button "Send me reset password instructions"

    expect_flash_message(
      "You will receive an email with instructions on how to reset your password in a few minutes.",
      type: :notice
    )

    expect(ActionMailer::Base.deliveries.count).to eq(1)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to include(user.email)
    expect(mail.subject).to eq("Reset password instructions")
  end

  it "shows success message even with invalid email but does not send email" do
    visit new_user_password_path
    fill_in "Email", with: "nonexistent@example.com"
    click_button "Send me reset password instructions"

    expect_flash_message(
      "You will receive an email with instructions on how to reset your password in a few minutes.",
      type: :notice
    )

    expect(ActionMailer::Base.deliveries.count).to eq(0)
  end

  it "allows user to reset password with valid token", :aggregate_failures do
    token = request_password_reset_for(user)
    expect(token).to be_present

    complete_password_reset(token, "newpassword123")
    expect_successful_password_reset

    sign_out_through_ui(user)
    sign_in_through_ui(name: user.name, password: "newpassword123")

    expect(page).to have_current_path(root_path)
  end

  it "shows error with invalid or expired token" do
    visit edit_user_password_path(reset_password_token: "invalid_token")

    fill_in "New password", with: "newpassword123"
    fill_in "Confirm your new password", with: "newpassword123"
    click_button "Change my password"

    expect(page).to have_content("Reset password token is invalid")
  end

  it "shows validation error when passwords don't match" do
    token = request_password_reset_for(user)
    expect(token).to be_present

    visit edit_user_password_path(reset_password_token: token)
    fill_in "New password", with: "newpassword123"
    fill_in "Confirm your new password", with: "different123"
    click_button "Change my password"

    expect(page).to have_content("Password confirmation doesn't match Password")
  end

  it "shows validation error when password is too short" do
    token = request_password_reset_for(user)
    expect(token).to be_present

    visit edit_user_password_path(reset_password_token: token)
    fill_in "New password", with: "12345"
    fill_in "Confirm your new password", with: "12345"
    click_button "Change my password"

    expect(page).to have_content("Password is too short (minimum is 6 characters)")
  end

  it "shows error when token has expired" do
    token = request_password_reset_for(user)
    expect(token).to be_present

    travel 7.hours do
      visit edit_user_password_path(reset_password_token: token)
      fill_in "New password", with: "newpassword123"
      fill_in "Confirm your new password", with: "newpassword123"
      click_button "Change my password"

      # Devise presents token expiry as invalid token in many setups; check for either
      expect(page).to have_content(/Reset password token (is invalid|has expired|is invalid or has expired)/i)
    end
  end
end
