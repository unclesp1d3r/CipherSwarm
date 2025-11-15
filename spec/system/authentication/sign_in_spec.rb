# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "User sign in" do
  let(:sign_in_page) { SignInPage.new(page) }
  let(:user) { create(:user) }

  describe "successful sign in" do
    it "allows user to sign in with valid credentials" do
      sign_in_page.visit_page
      expect(sign_in_page).to have_sign_in_form

      sign_in_page.sign_in_with(name: user.name, password: user.password)

      expect(page).to have_current_path(root_path)
      expect(page).to have_content(user.name)
    end
  end

  describe "failed sign in" do
    it "shows error message with invalid credentials" do
      sign_in_page.visit_page
      sign_in_page.sign_in_with_invalid_credentials

      expect(sign_in_page).to have_invalid_credentials_error
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe "locked account" do
    it "prevents sign in for locked accounts" do
      locked_user = create(:user)
      locked_user.lock_access!

      sign_in_page.visit_page
      sign_in_page.sign_in_with(name: locked_user.name, password: locked_user.password)

      expect(sign_in_page).to have_locked_account_error
    end
  end

  describe "sign out" do
    it "allows user to sign out" do
      sign_in_as(user)
      expect(page).to have_content(user.name)

      sign_out_via_ui(user)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_no_content(user.name)
    end
  end
end
