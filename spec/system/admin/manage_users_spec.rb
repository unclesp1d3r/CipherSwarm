# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Admin user management" do
  let!(:admin) { create_and_sign_in_admin }

  describe "admin accesses admin dashboard" do
    it "displays admin interface with users and projects" do
      visit admin_index_path

      expect(page).to have_content("Admin")
      expect(page).to have_content("Users")
      expect(page).to have_content("Projects")
    end
  end

  describe "admin creates new user" do
    it "creates user and locks by default" do
      visit admin_index_path
      click_link "New User"

      # Wait for modal/form to load
      expect(page).to have_field("Name", wait: 5)

      fill_in "Name", with: "New User"
      fill_in "Email", with: "newuser@example.com"
      fill_in "Password", with: "password123"
      fill_in "Password confirmation", with: "password123"
      click_button "Submit"

      # Wait for redirect after user creation
      expect(page).to have_current_path(admin_index_path, wait: 5)

      user = User.find_by(email: "newuser@example.com")
      expect(user).to be_present
      expect(user.access_locked?).to be true
    end
  end

  describe "admin locks user" do
    let!(:user) { create(:user) }

    it "locks user account" do
      visit admin_index_path

      expect(page).to have_content(user.name)
      find("#lock-user-#{user.id}").click

      # Wait for Turbo form submission and redirect
      expect(page).to have_current_path(admin_index_path, wait: 5)

      user.reload
      expect(user.access_locked?).to be true
    end
  end

  describe "admin unlocks user" do
    let!(:user) { create(:user) }

    before do
      user.lock_access!
    end

    it "unlocks user account" do
      visit admin_index_path

      expect(page).to have_content(user.name)
      find("#unlock-user-#{user.id}").click

      # Wait for Turbo form submission and redirect
      expect(page).to have_current_path(admin_index_path, wait: 5)

      user.reload
      expect(user.access_locked?).to be false
    end
  end

  describe "non-admin cannot access admin area" do
    let(:user) { create(:user) }

    it "prevents access to admin dashboard" do
      sign_out_via_ui(admin)
      sign_in_as(user)
      visit admin_index_path

      expect(page).to have_content("Not Authorized")
    end
  end
end
