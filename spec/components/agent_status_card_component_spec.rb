# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe AgentStatusCardComponent, type: :component do
  let(:user) { create(:user) }
  let(:agent) do
    create(:agent,
      user: user,
      state: :active,
      custom_label: "Test Agent",
      current_hash_rate: 1_000_000_000, # 1 GH/s
      last_seen_at: 5.minutes.ago)
  end

  before do
    # Set up Warden for authorization helpers
    # Create ability based on the user
    ability = Ability.new(user)
    allow(vc_test_controller).to receive_messages(current_user: user, user_signed_in?: true, current_ability: ability)
  end

  describe "rendering" do
    before do
      render_inline(described_class.new(agent: agent))
    end

    it "renders the card structure" do
      expect(page).to have_css(".card")
    end

    it "displays the agent name" do
      expect(page).to have_text("Test Agent")
    end

    it "displays the status badge with correct variant" do
      expect(page).to have_css(".badge.rounded-pill.text-bg-success", text: "Active")
    end

    it "displays the hash rate" do
      expect(page).to have_text("1 GH/s")
    end

    it "includes the agent's dom_id for Turbo Stream targeting" do
      expect(page).to have_css("#agent_#{agent.id}")
    end

    it "displays last seen time" do
      expect(page).to have_text("5 minutes ago")
    end
  end

  describe "error count display" do
    let(:recent_error) do
      create(:agent_error, agent: agent, created_at: 1.hour.ago)
    end

    let(:old_error) do
      create(:agent_error, agent: agent, created_at: 25.hours.ago)
    end

    before do
      recent_error
      old_error
      render_inline(described_class.new(agent: agent))
    end

    it "displays only errors from the last 24 hours" do
      expect(page).to have_text("Errors (24h): 1")
    end

    it "applies danger styling when errors exist" do
      expect(page).to have_css(".text-danger", text: /Errors/)
    end
  end

  describe "different agent states" do
    context "when agent is pending" do
      let(:agent) { create(:agent, user: user, state: :pending) }

      it "displays warning badge" do
        render_inline(described_class.new(agent: agent))
        expect(page).to have_css(".badge.rounded-pill.text-bg-warning", text: "Pending")
      end
    end

    context "when agent has error state" do
      let(:agent) { create(:agent, user: user, state: :error) }

      it "displays danger badge" do
        render_inline(described_class.new(agent: agent))
        expect(page).to have_css(".badge.rounded-pill.text-bg-danger", text: "Error")
      end

      it "applies border-danger styling to card" do
        render_inline(described_class.new(agent: agent))
        expect(page).to have_css(".card.border-danger")
      end
    end

    context "when agent is offline" do
      let(:agent) { create(:agent, user: user, state: :offline) }

      it "displays dark badge" do
        render_inline(described_class.new(agent: agent))
        expect(page).to have_css(".badge.rounded-pill.text-bg-dark", text: "Offline")
      end
    end

    context "when agent is stopped" do
      let(:agent) { create(:agent, user: user, state: :stopped) }

      it "displays secondary badge" do
        render_inline(described_class.new(agent: agent))
        expect(page).to have_css(".badge.rounded-pill.text-bg-secondary", text: "Stopped")
      end
    end
  end

  describe "with nil last_seen_at" do
    let(:agent) { create(:agent, user: user, last_seen_at: nil) }

    it "displays 'Not seen yet' text" do
      render_inline(described_class.new(agent: agent))
      expect(page).to have_text("Not seen yet")
    end
  end

  describe "with zero hash rate" do
    let(:agent) { create(:agent, user: user, current_hash_rate: 0) }

    it "displays '0 H/s' correctly" do
      render_inline(described_class.new(agent: agent))
      expect(page).to have_text("0 H/s")
    end
  end

  describe "helper methods" do
    subject(:component) { described_class.new(agent: agent) }

    describe "#error_count_last_24h" do
      let(:recent_errors) do
        create_list(:agent_error, 3, agent: agent, created_at: 12.hours.ago)
      end

      let(:old_errors) do
        create_list(:agent_error, 2, agent: agent, created_at: 30.hours.ago)
      end

      it "returns count of errors from last 24 hours only" do
        recent_errors
        old_errors
        expect(component.error_count_last_24h).to eq(3)
      end
    end

    describe "#status_badge_variant" do
      it "returns success for active state" do
        agent.state = "active"
        expect(component.status_badge_variant).to eq("success")
      end

      it "returns warning for pending state" do
        agent.state = "pending"
        expect(component.status_badge_variant).to eq("warning")
      end

      it "returns secondary for stopped state" do
        agent.state = "stopped"
        expect(component.status_badge_variant).to eq("secondary")
      end

      it "returns danger for error state" do
        agent.state = "error"
        expect(component.status_badge_variant).to eq("danger")
      end

      it "returns dark for offline state" do
        agent.state = "offline"
        expect(component.status_badge_variant).to eq("dark")
      end

      it "returns secondary for unknown state" do
        agent.state = "unknown"
        expect(component.status_badge_variant).to eq("secondary")
      end
    end

    describe "#card_classes" do
      it "includes h-100 for consistent height" do
        expect(component.card_classes).to include("h-100")
      end

      it "includes border-danger for error state" do
        agent.state = "error"
        expect(component.card_classes).to include("border-danger")
      end

      it "does not include border-danger for non-error states" do
        agent.state = "active"
        expect(component.card_classes).not_to include("border-danger")
      end
    end
  end
end
