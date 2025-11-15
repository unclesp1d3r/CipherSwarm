# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Create agent" do
  let(:user) { create_and_sign_in_admin }
  let(:agents_page) { AgentsIndexPage.new(page) }
  let(:agent_form) { AgentFormPage.new(page) }
  let(:project) { create(:project) }

  before do
    user.projects << project
  end

  describe "create agent with valid data" do
    it "creates a new agent and displays it in the list" do
      agents_page.visit_page
      agents_page.click_new_agent

      # Wait for form to be visible
      expect(page).to have_field(FormLabelsHelper::Agent.custom_label)

      agent_form.fill_custom_label("Test Agent")
      agent_form.toggle_enabled
      # Explicitly select the current user if user field is visible (admin only)
      if page.has_field?(FormLabelsHelper::Agent.user)
        agent_form.select_user(user)
      end
      agent_form.select_projects([project.name])
      agent_form.submit_form

      # Wait for redirect and agent creation
      expect(page).to have_content("Agent was successfully created", wait: 10)

      agent = Agent.find_by(custom_label: "Test Agent")
      expect(agent).to be_present
      expect(page).to have_current_path(agent_path(agent))
      expect(page).to have_content("Test Agent")
    end
  end

  describe "create agent with advanced configuration" do
    it "creates agent with advanced settings" do
      agents_page.visit_page
      agents_page.click_new_agent

      # Wait for form to be visible
      expect(page).to have_field(FormLabelsHelper::Agent.custom_label)

      agent_form.fill_custom_label("Advanced Agent")
      # Explicitly select the current user if user field is visible (admin only)
      if page.has_field?(FormLabelsHelper::Agent.user)
        agent_form.select_user(user)
      end
      agent_form.select_projects([project.name])
      agent_form.fill_advanced_config(
        FormLabelsHelper::Agent::AdvancedConfiguration.agent_update_interval => "30",
        FormLabelsHelper::Agent::AdvancedConfiguration.backend_device => "1,2"
      )
      agent_form.submit_form

      # Wait for redirect and agent creation
      expect(page).to have_content("Agent was successfully created", wait: 10)

      agent = Agent.find_by(custom_label: "Advanced Agent")
      expect(agent).to be_present
      expect(page).to have_current_path(agent_path(agent))
      expect(page).to have_content("Advanced Agent")
    end
  end

  describe "admin user can assign agent to another user" do
    let(:other_user) { create(:user) }
    let(:project) { create(:project) }
    let(:agents_page) { AgentsIndexPage.new(page) }
    let(:agent_form) { AgentFormPage.new(page) }

    before do
      # Use the top-level admin user instead of creating a new one
      user.projects << project
      other_user.projects << project
    end

    it "allows admin to assign agent to different user" do
      agents_page.visit_page
      agents_page.click_new_agent

      # Wait for form and check for user field - combine field checks
      expect(page).to have_field(FormLabelsHelper::Agent.custom_label).and have_field(FormLabelsHelper::Agent.user)

      agent_form.fill_custom_label("Admin Assigned Agent")
      agent_form.select_user(other_user)
      agent_form.select_projects([project.name])
      agent_form.submit_form

      # Wait for redirect and agent creation
      expect(page).to have_content("Agent was successfully created", wait: 10)

      agent = Agent.find_by(custom_label: "Admin Assigned Agent")
      # Combine agent presence and user assignment checks
      expect(agent).to be_present.and have_attributes(user: other_user)
      expect(page).to have_current_path(agent_path(agent))
    end
  end
end
