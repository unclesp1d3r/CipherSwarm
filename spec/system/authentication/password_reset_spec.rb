# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Password reset" do
  let(:user) { create(:user) }

  describe "request password reset" do
    it "sends password reset email" do
      visit new_user_session_path
      click_link "Forgot your password?"

      fill_in "Email", with: user.email
      click_button "Send me reset password instructions"

      expect(page).to have_content("You will receive an email with instructions")
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end
  end

  describe "reset password with valid token" do
    it "allows user to reset password" do
      token = user.send(:set_reset_password_token)
      visit edit_user_password_path(reset_password_token: token)

      fill_in "New password", with: "newpassword123"
      fill_in "Confirm your new password", with: "newpassword123"
      click_button "Change my password"

      expect(page).to have_content("Your password has been changed successfully")
      expect(page).to have_current_path(root_path)
    end
  end

  describe "reset password with invalid token" do
    it "shows error for invalid token" do
      visit edit_user_password_path(reset_password_token: "invalid_token")

      fill_in "New password", with: "newpassword123"
      fill_in "Confirm your new password", with: "newpassword123"
      click_button "Change my password"

      expect(page).to have_content("Reset password token is invalid")
    end
  end
end
