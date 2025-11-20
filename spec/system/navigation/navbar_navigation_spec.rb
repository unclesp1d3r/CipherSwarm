# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Navbar navigation" do
  describe "navbar displays correctly when signed in" do
    let(:user) { create_and_sign_in_user }

    it "shows navbar with user dropdown and tools" do
      visit root_path

      expect(page).to have_css("nav")
      expect(page).to have_content(user.name)
      expect(page).to have_content("Tools")
    end
  end

  describe "navigate via Tools dropdown" do
    let(:user) { create_and_sign_in_user }

    it "navigates to word lists from Tools dropdown", js: true do
      # Ensure user is signed in before visiting the page
      user

      visit root_path

      # Wait for navbar to load
      expect(page).to have_css("nav", wait: 5)

      # Ensure navbar is expanded (might be collapsed on mobile)
      click_button(class: "navbar-toggler") if page.has_css?("button.navbar-toggler", visible: true)

      # Find the Tools dropdown and click it
      find("a.dropdown-toggle", text: /Tools/i).click

      # Click the Word Lists link (Capybara can find it even if not visible)
      click_link "Word Lists"

      expect(page).to have_current_path(word_lists_path)
    end
  end

  describe "navigate via user dropdown" do
    let(:user) { create_and_sign_in_user }

    it "navigates to edit profile" do
      visit root_path

      find("a.nav-link.dropdown-toggle", text: user.name).click
      click_link "Edit Profile"

      expect(page).to have_current_path(edit_user_registration_path)
    end
  end

  describe "admin link visibility" do
    it "shows admin link for admin users" do
      admin = create_and_sign_in_admin
      visit root_path

      expect(page).to have_link("Admin Dashboards", href: admin_root_path)
    end

    it "hides admin link for regular users" do
      user = create_and_sign_in_user
      visit root_path
      # Wait for page to load before checking for absence
      expect(page).to have_css("nav")

      expect(page).to have_no_link(href: admin_root_path)
    end
  end
end
