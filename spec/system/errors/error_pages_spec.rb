# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Error pages" do
  describe "404 Not Found" do
    it "handles non-existent routes" do
      visit "/nonexistent"

      expect(page).to have_content("Routing Error")
    end
  end

  describe "403 Forbidden / Unauthorized access" do
    let(:other_project) { create(:project) }
    let(:other_hash_list) { create(:hash_list, project: other_project) }

    it "redirects unauthenticated users to the login page" do
      visit hash_list_path(other_hash_list)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("Log in")
    end
  end

  describe "422 Unprocessable Entity" do
    let(:user) { create_and_sign_in_user }
    let(:agent) { create(:agent, user: user, custom_label: "Original") }
    # rubocop:disable RSpec/LetSetup
    let!(:other_agent) { create(:agent, user: user, custom_label: "Existing") }
    # rubocop:enable RSpec/LetSetup

    it "displays validation errors in form" do
      visit edit_agent_path(agent)

      fill_in FormLabelsHelper::Agent.custom_label, with: "Existing"
      click_button "Submit"

      expect(page).to have_content("Custom label has already been taken")
    end
  end

  describe "flash message display" do
    before { create_and_sign_in_user }

    it "displays success flash message" do
      visit agents_path
      # Wait for the New Agent link to be available
      # Verify link exists or visit directly
      if page.has_link?(href: new_agent_path)
        find("a[href='#{new_agent_path}']").click
      else
        visit new_agent_path
      end

      # Wait for form to load
      expect(page).to have_field(FormLabelsHelper::Agent.custom_label, wait: 5)

      fill_in FormLabelsHelper::Agent.custom_label, with: "Flash Test Agent"
      click_button "Submit"

      expect(page).to have_css(".alert.alert-success")
      expect(page).to have_content("Agent was successfully created")
    end
  end

  describe "error handling in forms" do
    let(:user) { create_and_sign_in_user }
    let(:agent) { create(:agent, user: user, custom_label: "Original") }
    # rubocop:disable RSpec/LetSetup
    let!(:other_agent) { create(:agent, user: user, custom_label: "Duplicate") }
    # rubocop:enable RSpec/LetSetup

    it "retains form values after validation error" do
      visit edit_agent_path(agent)

      fill_in FormLabelsHelper::Agent.custom_label, with: "Duplicate"
      click_button "Submit"

      expect(page).to have_field(FormLabelsHelper::Agent.custom_label, with: "Duplicate")
      expect(page).to have_content("Custom label has already been taken")
    end
  end
end
