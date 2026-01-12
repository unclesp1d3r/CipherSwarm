# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe AgentDetailTabsComponent, type: :component do
  subject(:component) { described_class.new(agent: agent, errors: errors, pagy: pagy) }

  let(:agent) do
    create(:agent,
      state: :active,
      current_hash_rate: 1_000_000_000,
      current_temperature: 65,
      current_utilization: 90,
      last_seen_at: 5.minutes.ago)
  end

  let(:errors) { create_list(:agent_error, 2, agent: agent) }
  let(:pagy) { Pagy.new(count: errors.size, page: 1, items: 10) }

  def render_component(&)
    render_inline(component, &)
  end


  describe "rendering" do
    before do
      render_component do |tabs|
        tabs.with_overview_tab { "Overview content" }
        tabs.with_errors_tab { "Errors content" }
        tabs.with_configuration_tab { "Configuration content" }
        tabs.with_capabilities_tab { "Capabilities content" }
      end
    end

    it "sets tabs controller with default active value" do
      expect(page).to have_css("[data-controller='tabs'][data-tabs-active-value='0']")
    end

    it "renders all four tab navigation items" do
      expect(page).to have_css("a##{component.tab_id('overview')}", text: "Overview")
      expect(page).to have_css("a##{component.tab_id('errors')}", text: "Errors")
      expect(page).to have_css("a##{component.tab_id('configuration')}", text: "Configuration")
      expect(page).to have_css("a##{component.tab_id('capabilities')}", text: "Capabilities")
    end

    it "applies tab data targets and actions" do
      expect(page).to have_css("a##{component.tab_id('overview')}[data-tabs-target='tab'][data-action='click->tabs#showTab']")
      expect(page).to have_css("a##{component.tab_id('errors')}[data-tabs-target='tab'][data-action='click->tabs#showTab']")
    end

    it "renders tab panels with correct ids and targets" do
      expect(page).to have_css("##{component.panel_id('overview')}[data-tabs-target='panel']")
      expect(page).to have_css("##{component.panel_id('errors')}[data-tabs-target='panel']")
      expect(page).to have_css("##{component.panel_id('configuration')}[data-tabs-target='panel']")
      expect(page).to have_css("##{component.panel_id('capabilities')}[data-tabs-target='panel']")
    end

    it "shows overview tab as active and hides others" do
      expect(page).to have_css("##{component.panel_id('overview')}.tab-pane.active")
      expect(page).to have_css("##{component.panel_id('errors')}.tab-pane.d-none")
      expect(page).to have_css("##{component.panel_id('configuration')}.tab-pane.d-none")
      expect(page).to have_css("##{component.panel_id('capabilities')}.tab-pane.d-none")
    end

    it "renders provided slot content" do
      expect(page).to have_text("Overview content")
      expect(page).to have_text("Errors content")
      expect(page).to have_text("Configuration content")
      expect(page).to have_text("Capabilities content")
    end
  end

  describe "helper methods" do
    before do
      render_component do |tabs|
        tabs.with_overview_tab { "Overview" }
        tabs.with_errors_tab { "Errors" }
        tabs.with_configuration_tab { "Configuration" }
        tabs.with_capabilities_tab { "Capabilities" }
      end
    end

    it "builds tab id with agent prefix" do
      expect(component.tab_id("overview")).to eq("agent_#{agent.id}_overview_tab")
    end

    it "builds panel id with agent prefix" do
      expect(component.panel_id("errors")).to eq("agent_#{agent.id}_errors_panel")
    end
  end

  describe "edge cases" do
    context "with no errors" do
      let(:errors) { [] }

      it "still renders all tab panels" do
        render_component do |tabs|
          tabs.with_overview_tab { "O" }
          tabs.with_errors_tab { "E" }
          tabs.with_configuration_tab { "C" }
          tabs.with_capabilities_tab { "P" }
        end

        expect(page).to have_css("##{component.panel_id('errors')}")
      end
    end

    context "with varying agent states" do
      %w[pending active error stopped offline].each do |state|
        context "when state is #{state}" do
          let(:agent) { create(:agent, state: state) }

          it "renders tabs without errors" do
            expect do
              render_component do |tabs|
                tabs.with_overview_tab { "Overview" }
                tabs.with_errors_tab { "Errors" }
                tabs.with_configuration_tab { "Configuration" }
                tabs.with_capabilities_tab { "Capabilities" }
              end
            end.not_to raise_error
          end
        end
      end
    end
  end
end
