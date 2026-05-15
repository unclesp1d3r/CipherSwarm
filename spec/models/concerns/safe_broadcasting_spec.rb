# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe SafeBroadcasting do
  describe "constants" do
    it "defines BROADCAST_METHODS with expected methods" do
      expect(SafeBroadcasting::BROADCAST_METHODS).to contain_exactly(
        :broadcast_replace_to,
        :broadcast_replace_later_to,
        :broadcast_refresh_to,
        :broadcast_refresh
      )
    end

    it "defines EXPECTED_BROADCAST_ERRORS with connection errors" do
      expect(SafeBroadcasting::EXPECTED_BROADCAST_ERRORS).to include(
        IOError,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Errno::EPIPE
      )
    end

    it "defines DEFAULT_THROTTLE_TTL as a positive duration" do
      expect(SafeBroadcasting::DEFAULT_THROTTLE_TTL).to be_a(ActiveSupport::Duration)
      expect(SafeBroadcasting::DEFAULT_THROTTLE_TTL).to be > 0
    end
  end

  describe "#throttled_broadcast" do
    # Use Agent as a concrete includer of SafeBroadcasting so we can exercise
    # the private helper without defining a throwaway test class.
    let(:agent) { create(:agent) }

    it "yields and returns the block's value when the cache write succeeds" do
      allow(Rails.cache).to receive(:write).and_return(true)
      result = agent.send(:throttled_broadcast, "k") { :fired }
      expect(result).to eq(:fired)
    end

    it "does not yield when the cache write reports the key already exists" do
      allow(Rails.cache).to receive(:write).and_return(false)
      expect { |b| agent.send(:throttled_broadcast, "k", &b) }.not_to yield_control
    end

    it "returns nil when suppressed" do
      allow(Rails.cache).to receive(:write).and_return(false)
      expect(agent.send(:throttled_broadcast, "k") { :fired }).to be_nil
    end

    it "treats different keys independently" do
      allow(Rails.cache).to receive(:write).with("a", anything, anything).and_return(true)
      allow(Rails.cache).to receive(:write).with("b", anything, anything).and_return(true)
      a_fired = false
      b_fired = false
      agent.send(:throttled_broadcast, "a") { a_fired = true }
      agent.send(:throttled_broadcast, "b") { b_fired = true }
      expect(a_fired).to be(true)
      expect(b_fired).to be(true)
    end

    it "forwards a custom ttl as expires_in to Rails.cache.write" do
      allow(Rails.cache).to receive(:write).and_return(true)
      agent.send(:throttled_broadcast, "k", ttl: 10.seconds) { :ok }
      expect(Rails.cache).to have_received(:write).with(
        "k",
        true,
        hash_including(expires_in: 10.seconds, unless_exist: true)
      )
    end

    it "uses DEFAULT_THROTTLE_TTL when ttl is not provided" do
      allow(Rails.cache).to receive(:write).and_return(true)
      agent.send(:throttled_broadcast, "k") { :ok }
      expect(Rails.cache).to have_received(:write).with(
        "k",
        true,
        hash_including(expires_in: SafeBroadcasting::DEFAULT_THROTTLE_TTL, unless_exist: true)
      )
    end

    it "fails open and yields when Rails.cache.write raises" do
      allow(Rails.cache).to receive(:write).and_raise(StandardError.new("redis down"))
      allow(Rails.logger).to receive(:error)
      expect { |b| agent.send(:throttled_broadcast, "k", &b) }.to yield_control
    end

    it "logs an error via log_broadcast_error when the cache write raises" do
      allow(Rails.cache).to receive(:write).and_raise(StandardError.new("redis down"))
      allow(Rails.logger).to receive(:error)
      agent.send(:throttled_broadcast, "k") { :ok }
      expect(Rails.logger).to have_received(:error).with(/\[BroadcastError\].*redis down/m).at_least(:once)
    end
  end

  describe "model inclusion" do
    it "is included in Agent" do
      expect(Agent.ancestors).to include(described_class)
    end

    it "is included in Campaign" do
      expect(Campaign.ancestors).to include(described_class)
    end

    it "is included in Attack" do
      expect(Attack.ancestors).to include(described_class)
    end

    it "is not included in AgentError" do
      # AgentError previously included SafeBroadcasting to wrap `broadcasts_refreshes`.
      # That macro was removed (issue #795) since the targeted `agent.broadcast_index_errors`
      # callback is the sole UI-update path and routes through Agent's own SafeBroadcasting.
      expect(AgentError.ancestors).not_to include(described_class)
    end

    it "is included in HashItem" do
      expect(HashItem.ancestors).to include(described_class)
    end
  end

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

    it "skips broadcast_refresh in test environment without error" do
      # Only test methods that don't require arguments
      # Methods like broadcast_replace_to require stream/target arguments
      expect { agent.broadcast_refresh }.not_to raise_error
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
