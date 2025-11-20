# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Delete agent" do
  let(:user) { create_and_sign_in_user }
  let(:agents_page) { AgentsIndexPage.new(page) }
  # rubocop:disable RSpec/LetSetup
  let!(:agent) { create(:agent, user: user, custom_label: "To Delete") }
  # rubocop:enable RSpec/LetSetup

  describe "delete agent successfully" do
    it "removes agent from list after confirmation" do
      agents_page.visit_page
      expect(page).to have_content("To Delete")

      agents_page.click_delete_agent("To Delete")

      expect(page).to have_current_path(agents_path)
      expect_flash_message("Agent was successfully destroyed.")
      expect(page).to have_no_content("To Delete")
    end
  end

  describe "cancel agent deletion" do
    it "keeps agent in list when deletion is cancelled" do
      agents_page.visit_page

      dismiss_confirm do
        within(agents_page.agent_row("To Delete")) do
          first("button.btn-danger").click
        end
      end

      expect(page).to have_content("To Delete")
    end
  end

  describe "authorization" do
    let(:other_user) { create(:user) }
    let!(:other_agent) { create(:agent, user: other_user) }

    it "prevents non-admin from deleting another user's agent" do
      agents_page.visit_page

      # Non-admin users should not see other users' agents at all
      expect(page).to have_no_content(other_agent.custom_label || other_agent.host_name)
    end
  end
end
