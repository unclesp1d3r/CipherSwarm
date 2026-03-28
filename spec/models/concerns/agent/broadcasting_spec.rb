# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe Agent::Broadcasting do
  let(:agent) { create(:agent) }

  describe "model inclusion" do
    it "is included in Agent" do
      expect(Agent.ancestors).to include(described_class)
    end
  end

  describe "constants" do
    it "defines OVERVIEW_BROADCAST_FIELDS" do
      expect(Agent::Broadcasting::OVERVIEW_BROADCAST_FIELDS).to contain_exactly(
        "state", "current_activity", "current_hash_rate", "current_temperature", "current_utilization"
      )
    end

    it "defines CONFIGURATION_BROADCAST_FIELDS" do
      expect(Agent::Broadcasting::CONFIGURATION_BROADCAST_FIELDS).to contain_exactly(
        "enabled", "client_signature", "last_ipaddress", "advanced_configuration",
        "custom_label", "operating_system", "user_id"
      )
    end
  end

  describe "after_update_commit callback" do
    it "registers broadcast callbacks on update commit" do
      callback_methods = Agent._commit_callbacks.map(&:filter)
      expect(callback_methods).to include(:broadcast_tab_updates)
      expect(callback_methods).to include(:broadcast_index_state)
      expect(callback_methods).to include(:broadcast_index_last_seen)
    end
  end

  describe "#broadcast_index_state" do
    context "when state has not changed" do
      it "does not broadcast" do
        # Stub before the update so the callback is captured too
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(host_name: "new-host-name")
        # The callback fires broadcast_index_state which checks saved_change_to_state?
        # Since state didn't change, broadcast_replace_later_to should NOT be called
        # with the index_state target (though it may be called for overview tab)
        expect(agent).not_to have_received(:broadcast_replace_later_to).with(
          agent,
          hash_including(target: ActionView::RecordIdentifier.dom_id(agent, :index_state))
        )
      end
    end

    context "when state has changed" do
      it "broadcasts a replacement to the index state target" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update_column(:state, "pending") # rubocop:disable Rails/SkipsModelValidations
        agent.activate!
        # The after_update_commit callback fires and calls broadcast_index_state
        expect(agent).to have_received(:broadcast_replace_later_to).with(
          agent,
          hash_including(
            target: ActionView::RecordIdentifier.dom_id(agent, :index_state),
            partial: "agents/index_state"
          )
        )
      end
    end
  end

  describe "#broadcast_index_errors" do
    it "broadcasts a replacement to the index errors target" do
      allow(agent).to receive(:broadcast_replace_later_to)
      agent.broadcast_index_errors
      expect(agent).to have_received(:broadcast_replace_later_to).with(
        agent,
        hash_including(
          target: ActionView::RecordIdentifier.dom_id(agent, :index_errors),
          partial: "agents/index_errors"
        )
      )
    end
  end

  describe "#broadcast_index_last_seen" do
    context "when last_seen_at has not changed" do
      it "does not broadcast" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(host_name: "another-host")
        expect(agent).not_to have_received(:broadcast_replace_later_to).with(
          agent,
          hash_including(target: ActionView::RecordIdentifier.dom_id(agent, :index_last_seen))
        )
      end
    end

    context "when last_seen_at has changed" do
      it "broadcasts a replacement to the index last seen target" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(last_seen_at: Time.current)
        # The callback fires broadcast_index_last_seen which detects the change
        expect(agent).to have_received(:broadcast_replace_later_to).with(
          agent,
          hash_including(
            target: ActionView::RecordIdentifier.dom_id(agent, :index_last_seen),
            partial: "agents/index_last_seen"
          )
        )
      end
    end
  end

  describe "#broadcast_tab_updates" do
    context "when overview-relevant fields change" do
      it "broadcasts the overview tab" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(current_activity: "cracking")
        expect(agent).to have_received(:broadcast_replace_later_to).with(
          [agent, :overview],
          hash_including(
            target: ActionView::RecordIdentifier.dom_id(agent, :overview),
            partial: "agents/overview_tab"
          )
        )
      end
    end

    context "when non-overview fields change" do
      it "does not broadcast the overview tab" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(last_seen_at: Time.current)
        expect(agent).not_to have_received(:broadcast_replace_later_to).with(
          [agent, :overview],
          anything
        )
      end
    end

    context "when configuration-relevant fields change" do
      it "broadcasts the configuration tab" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(enabled: !agent.enabled)
        expect(agent).to have_received(:broadcast_replace_later_to).with(
          [agent, :configuration],
          hash_including(
            target: ActionView::RecordIdentifier.dom_id(agent, :configuration),
            partial: "agents/configuration_tab"
          )
        )
      end
    end

    context "when non-configuration fields change" do
      it "does not broadcast the configuration tab" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(last_seen_at: Time.current)
        expect(agent).not_to have_received(:broadcast_replace_later_to).with(
          [agent, :configuration],
          anything
        )
      end
    end

    context "when state changes" do
      it "broadcasts the capabilities tab" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update_column(:state, "pending") # rubocop:disable Rails/SkipsModelValidations
        agent.activate!
        expect(agent).to have_received(:broadcast_replace_later_to).with(
          [agent, :capabilities],
          hash_including(
            target: ActionView::RecordIdentifier.dom_id(agent, :capabilities),
            partial: "agents/capabilities_tab"
          )
        ).once
      end
    end

    context "when state does not change" do
      it "does not broadcast the capabilities tab" do
        allow(agent).to receive(:broadcast_replace_later_to)
        agent.update!(last_seen_at: Time.current)
        expect(agent).not_to have_received(:broadcast_replace_later_to).with(
          [agent, :capabilities],
          anything
        )
      end
    end
  end
end
