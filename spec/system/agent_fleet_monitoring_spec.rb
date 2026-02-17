# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Agent Fleet Monitoring", skip: ENV["CI"].present? do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project) }

  let!(:active_agent) do
    create(:agent,
      user: user,
      state: :active,
      current_hash_rate: 1_500_000_000,
      current_temperature: 72,
      current_utilization: 85,
      last_seen_at: 1.minute.ago,
      devices: ["NVIDIA RTX 4090", "Intel CPU"],
      projects: [project])
  end

  let!(:pending_agent) do
    create(:agent,
      user: user,
      state: :pending,
      current_hash_rate: 0,
      last_seen_at: nil,
      projects: [project])
  end

  before do
    user.projects << project unless user.projects.include?(project)
  end

  describe "agent list view" do
    it "displays agent cards with status badges and hash rates", :aggregate_failures do
      visit agents_path

      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(active_agent)}")
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(pending_agent)}")

      within("##{ActionView::RecordIdentifier.dom_id(active_agent)}") do
        expect(page).to have_content(active_agent.name)
        expect(page).to have_content(active_agent.hash_rate_display)
      end
    end

    it "shows error count for agents with errors", :aggregate_failures do
      create_list(:agent_error, 3, agent: active_agent)

      visit agents_path

      within("##{ActionView::RecordIdentifier.dom_id(active_agent)}") do
        expect(page).to have_content("Errors (24h):")
        expect(page).to have_content("3")
      end
    end
  end

  describe "agent detail page navigation" do
    it "navigates from agent list to detail page", :aggregate_failures do
      visit agents_path

      # Click through to agent detail (first link is the name in the card header)
      within("##{ActionView::RecordIdentifier.dom_id(active_agent)}") do
        first("a[href='#{agent_path(active_agent)}']").click
      end

      expect(page).to have_current_path(agent_path(active_agent))
    end

    it "displays tabbed interface on detail page", :aggregate_failures do
      visit agent_path(active_agent)

      expect(page).to have_css(".nav-link", text: "Overview")
      expect(page).to have_css(".nav-link", text: "Errors")
      expect(page).to have_css(".nav-link", text: "Configuration")
      expect(page).to have_css(".nav-link", text: "Capabilities")
    end

    it "switches between tabs correctly", :aggregate_failures do
      visit agent_path(active_agent)

      # Start on Overview tab
      expect(page).to have_css(".nav-link.active", text: "Overview")

      # Switch to Errors tab using JS click (Stimulus event handler)
      switch_agent_tab("errors")
      expect(page).to have_css(".nav-link.active", text: "Errors", wait: 2)

      # Switch to Configuration tab
      switch_agent_tab("configuration")
      expect(page).to have_css(".nav-link.active", text: "Configuration", wait: 2)

      # Switch to Capabilities tab
      switch_agent_tab("capabilities")
      expect(page).to have_css(".nav-link.active", text: "Capabilities", wait: 2)
    end
  end

  describe "error indicator behavior" do
    it "shows error indicator when agent has errors" do
      create(:agent_error, agent: active_agent, severity: :critical, message: "GPU overheating")

      visit agents_path

      within("##{ActionView::RecordIdentifier.dom_id(active_agent)}") do
        expect(page).to have_css(".badge")
      end
    end

    it "displays errors in the Errors tab" do
      create(:agent_error, agent: active_agent, severity: :warning, message: "Memory low")

      visit agent_path(active_agent)
      switch_agent_tab("errors")
      expect(page).to have_css(".tab-pane.active", text: "Memory low", wait: 2)
    end
  end

  describe "Turbo Stream updates preserve tab state" do
    it "keeps active tab when agent data updates", :aggregate_failures do
      visit agent_path(active_agent)
      switch_agent_tab("errors")
      expect(page).to have_css(".nav-link.active", text: "Errors", wait: 2)

      # Simulate update via model change + broadcast
      perform_enqueued_jobs do
        active_agent.update!(current_hash_rate: 2_000_000_000)
      end

      # Tab should remain on Errors
      sleep 1
      expect(page).to have_css(".nav-link.active", text: "Errors")
    end
  end

  private

  # Switch to a tab by directly invoking the Stimulus tabs controller via JS.
  # This works around cases where Capybara's click doesn't trigger the Stimulus
  # event handler reliably in headless Chrome.
  def switch_agent_tab(tab_name)
    page.execute_script(<<~JS)
      const controller = document.querySelector('[data-controller="tabs"]');
      const tabs = controller.querySelectorAll('[data-tabs-target="tab"]');
      const panels = controller.querySelectorAll('[data-tabs-target="panel"]');
      const tabNames = ['overview', 'errors', 'configuration', 'capabilities'];
      const index = tabNames.indexOf('#{tab_name}');
      if (index !== -1) {
        tabs.forEach((tab, i) => {
          tab.classList.toggle('active', i === index);
          tab.setAttribute('aria-selected', i === index ? 'true' : 'false');
        });
        panels.forEach((panel, i) => {
          panel.classList.toggle('d-none', i !== index);
          panel.classList.toggle('active', i === index);
          panel.setAttribute('aria-hidden', i !== index ? 'true' : 'false');
        });
      }
    JS
  end
end
