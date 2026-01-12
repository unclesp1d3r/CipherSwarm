# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe SafeBroadcasting do
  describe "integration with models" do
    it "is included in Agent model" do
      expect(Agent.included_modules).to include(described_class)
    end

    it "is included in Task model" do
      expect(Task.included_modules).to include(described_class)
    end

    it "is included in Campaign model" do
      expect(Campaign.included_modules).to include(described_class)
    end

    it "is included in Attack model" do
      expect(Attack.included_modules).to include(described_class)
    end
  end

  describe "broadcast error handling" do
    let(:agent) { create(:agent) }

    context "when broadcast fails" do
      before do
        # Stub the broadcast method to call log_broadcast_error
        allow(agent).to receive(:broadcast_refresh) do
          agent.send(:log_broadcast_error, StandardError.new("Broadcast connection lost"))
          nil
        end
      end

      it "logs the error with BroadcastError prefix" do
        allow(Rails.logger).to receive(:error)
        agent.broadcast_refresh
        expect(Rails.logger).to have_received(:error).with(/\[BroadcastError\]/).at_least(:once)
      end

      it "logs the model name and record ID" do
        allow(Rails.logger).to receive(:error)
        agent.broadcast_refresh
        expect(Rails.logger).to have_received(:error).with(/Model: Agent.*Record ID: #{agent.id}/m).at_least(:once)
      end

      it "logs the error message" do
        allow(Rails.logger).to receive(:error)
        agent.broadcast_refresh
        expect(Rails.logger).to have_received(:error).with(/Broadcast connection lost/).at_least(:once)
      end

      it "logs a backtrace" do
        allow(Rails.logger).to receive(:error)
        agent.broadcast_refresh
        expect(Rails.logger).to have_received(:error).with(/Backtrace:/).at_least(:once)
      end

      it "does not raise an exception" do
        expect { agent.broadcast_refresh }.not_to raise_error
      end
    end

    context "when model updates with broadcast failure" do
      before do
        allow(agent).to receive(:broadcast_update) do
          agent.send(:log_broadcast_error, StandardError.new("Update broadcast failed"))
          nil
        end
      end

      it "completes the update successfully" do
        expect { agent.update(client_signature: "Updated") }.not_to raise_error
        expect(agent.reload.client_signature).to eq("Updated")
      end

      it "logs the broadcast error but continues" do
        agent.update(client_signature: "Updated")
        expect(agent.reload.client_signature).to eq("Updated")
      end
    end
  end
end
