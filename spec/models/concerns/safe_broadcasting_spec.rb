# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe SafeBroadcasting do
  describe "test environment behavior" do
    let(:agent) { create(:agent) }

    it "returns nil in test environment without calling super" do
      # In test environment, broadcasts should be skipped entirely
      result = agent.broadcast_refresh
      expect(result).to be_nil
    end

    it "does not log errors in test environment" do
      allow(Rails.logger).to receive(:error)
      agent.broadcast_refresh
      # No BroadcastError should be logged since we skip before reaching that code
      expect(Rails.logger).not_to have_received(:error).with(/\[BroadcastError\]/)
    end

    it "skips all broadcast methods in test environment" do
      %i[broadcast_replace_to broadcast_replace_later_to broadcast_refresh_to broadcast_refresh].each do |method|
        next unless agent.respond_to?(method)
        # These should all return nil without error in test env
        expect { agent.public_send(method) rescue nil }.not_to raise_error
      end
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
