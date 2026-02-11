# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Tabs controller regressions" do
  let(:agent_page) { AgentDetailPage.new(page) }
  let(:user) { create_and_sign_in_user }

  let!(:agent) do
    create(:agent,
      user: user,
      state: :active,
      current_hash_rate: 1_000_000_000,
      last_seen_at: 5.minutes.ago)
  end

  before do
    agent_project = agent.projects.first
    user.projects << agent_project unless user.projects.include?(agent_project)
  end

  describe "switch action and .active class on panels" do
    it "applies active class to visible panel and removes from hidden panels", :aggregate_failures do
      agent_page.visit_page(agent)

      # Overview panel starts as active
      expect(agent_page.has_active_tab?("Overview")).to be true

      # Switch to Errors tab
      agent_page.click_tab("Errors")
      expect(agent_page.has_active_tab?("Errors")).to be true
      expect(agent_page.has_active_tab?("Overview")).to be false

      # Switch to Configuration tab
      agent_page.click_tab("Configuration")
      expect(agent_page.has_active_tab?("Configuration")).to be true
      expect(agent_page.has_active_tab?("Errors")).to be false

      # Switch to Capabilities tab
      agent_page.click_tab("Capabilities")
      expect(agent_page.has_active_tab?("Capabilities")).to be true
      expect(agent_page.has_active_tab?("Configuration")).to be false

      # Switch back to Overview tab
      agent_page.click_tab("Overview")
      expect(agent_page.has_active_tab?("Overview")).to be true
      expect(agent_page.has_active_tab?("Capabilities")).to be false
    end

    it "uses click->tabs#switch data-action on tab links" do
      agent_page.visit_page(agent)

      tab_links = page.all("[data-tabs-target='tab']")
      tab_links.each do |tab_link|
        expect(tab_link[:"data-action"]).to eq("click->tabs#switch")
      end
    end
  end
end
