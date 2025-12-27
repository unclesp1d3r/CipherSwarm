# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# rubocop:disable RSpec/MultipleDescribes
RSpec.describe "Edit agent" do
  let(:user) { create_and_sign_in_user }
  let(:agents_page) { AgentsIndexPage.new(page) }
  let(:agent_form) { AgentFormPage.new(page) }
  let!(:agent) { create(:agent, user: user, custom_label: "Original Label") }
  let(:project) { create(:project) }

  describe "edit agent successfully" do
    before do
      user.projects << project
    end

    it "updates agent and reflects changes in list" do
      agents_page.visit_page
      agents_page.click_edit_agent(agent.custom_label || agent.host_name)

      agent_form.fill_custom_label("Updated Label")
      agent_form.toggle_enabled
      agent_form.submit_form

      expect(page).to have_current_path(agent_path(agent))
      expect_flash_message("Agent was successfully updated.")
      expect(page).to have_content("Updated Label")
    end
  end

  describe "edit agent with validation errors" do
    # rubocop:disable RSpec/LetSetup
    let!(:other_agent) { create(:agent, user: user, custom_label: "Existing Label") }
    # rubocop:enable RSpec/LetSetup

    before do
      user.projects << project
    end

    it "shows validation errors for duplicate custom label" do
      agents_page.visit_page
      agents_page.click_edit_agent(agent.custom_label || agent.host_name)

      agent_form.fill_custom_label("Existing Label")
      agent_form.submit_form

      expect(agent_form.has_validation_error?("Custom label has already been taken")).to be true
    end
  end

  describe "authorization" do
    let(:other_user) { create(:user) }
    let(:other_agent) { create(:agent, user: other_user) }

    it "prevents non-admin from editing another user's agent" do
      agents_page.visit_page

      expect(page).to have_no_link("Edit", href: edit_agent_path(other_agent))
    end
  end
end

RSpec.describe "Edit agent - admin" do
  let(:agents_page) { AgentsIndexPage.new(page) }
  let(:agent_form) { AgentFormPage.new(page) }
  let(:other_user) { create(:user) }
  let!(:other_agent) { create(:agent, user: other_user, custom_label: "Target Agent") }

  before do
    admin = create_and_sign_in_admin
    # Ensure admin is part of the project to see the agent
    admin.projects << other_agent.projects.first
  end

  it "allows admin to edit any agent" do
    agents_page.visit_page
    agents_page.click_edit_agent(other_agent.custom_label || other_agent.host_name)

    agent_form.fill_custom_label("Admin Updated")
    agent_form.submit_form

    expect(page).to have_current_path(agent_path(other_agent))
    expect(page).to have_content("Admin Updated")
  end
end
