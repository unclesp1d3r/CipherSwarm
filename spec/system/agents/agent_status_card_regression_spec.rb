# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Agent status card regressions" do
  let(:agents_index) { AgentsIndexPage.new(page) }
  let(:user) { create_and_sign_in_user }

  before do
    agents.each do |agent|
      agent_project = agent.projects.first
      user.projects << agent_project unless user.projects.include?(agent_project)
    end
  end

  describe "StatusPillComponent badges for agent states" do
    let!(:active_agent) { create(:agent, user: user, state: :active, custom_label: "Active Agent") }
    let!(:pending_agent) { create(:agent, user: user, state: :pending, custom_label: "Pending Agent") }
    let!(:stopped_agent) { create(:agent, user: user, state: :stopped, custom_label: "Stopped Agent") }
    let!(:error_agent) { create(:agent, user: user, state: :error, custom_label: "Error Agent") }
    let!(:offline_agent) { create(:agent, user: user, state: :offline, custom_label: "Offline Agent") }
    let(:agents) { [active_agent, pending_agent, stopped_agent, error_agent, offline_agent] }

    before { agents_index.visit_page }

    it "renders success badge for active agent" do
      within(agents_index.agent_card("Active Agent")) do
        expect(page).to have_css(".badge.rounded-pill.text-bg-success", text: "Active")
      end
    end

    it "renders warning badge for pending agent" do
      within(agents_index.agent_card("Pending Agent")) do
        expect(page).to have_css(".badge.rounded-pill.text-bg-warning", text: "Pending")
      end
    end

    it "renders secondary badge for stopped agent" do
      within(agents_index.agent_card("Stopped Agent")) do
        expect(page).to have_css(".badge.rounded-pill.text-bg-secondary", text: "Stopped")
      end
    end

    it "renders danger badge and border for error agent" do
      within(agents_index.agent_card("Error Agent")) do
        expect(page).to have_css(".badge.rounded-pill.text-bg-danger", text: "Error")
        expect(page).to have_css(".card.border-danger")
      end
    end

    it "renders dark badge for offline agent" do
      within(agents_index.agent_card("Offline Agent")) do
        expect(page).to have_css(".badge.rounded-pill.text-bg-dark", text: "Offline")
      end
    end
  end

  describe "agent name links to detail page" do
    let!(:agent) do
      create(:agent, user: user, state: :active, custom_label: "Linked Agent",
                     current_hash_rate: 500_000_000)
    end
    let(:agents) { [agent] }

    it "navigates to agent detail when clicking the agent name" do
      agents_index.visit_page

      within(agents_index.agent_card("Linked Agent")) do
        click_link "Linked Agent"
      end

      expect(page).to have_current_path(agent_path(agent))
    end
  end
end
