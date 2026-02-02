# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe StatusSubmissionService do
  let(:project) { create(:project) }
  let(:hash_type) { create(:hash_type) }
  let(:hash_list) { create(:hash_list, project: project, hash_type: hash_type, processed: true) }
  let(:campaign) { create(:campaign, hash_list: hash_list, project: project) }
  let(:attack) { create(:attack, campaign: campaign) }
  let(:agent) { create(:agent) }
  let(:task) { create(:task, attack: attack, agent: agent, state: "running") }

  let(:valid_status_params) do
    {
      original_line: "Status: Running",
      session: "test_session",
      time: Time.current,
      status: 3,
      target: "target_hash",
      progress: [100, 1000],
      restore_point: 100,
      recovered_hashes: [1, 10],
      recovered_salts: [0, 1],
      rejected: 0,
      time_start: 1.hour.ago,
      estimated_stop: 1.hour.from_now,
      hashcat_guess: {
        guess_base: "wordlist.txt",
        guess_base_count: 1000,
        guess_base_offset: 0,
        guess_base_percentage: 10.0,
        guess_mod: "",
        guess_mod_count: 0,
        guess_mod_offset: 0,
        guess_mod_percentage: 0.0,
        guess_mode: 0
      },
      device_statuses: [
        {
          device_id: 1,
          device_name: "GPU #1",
          device_type: "GPU",
          speed: 1_000_000,
          utilization: 95,
          temperature: 65
        }
      ]
    }
  end

  describe "#call" do
    subject(:result) { described_class.new(task: task, status_params: status_params).call }

    context "with valid parameters" do
      let(:status_params) { valid_status_params }

      it "returns a successful result" do
        expect(result.success?).to be true
      end

      it "returns :ok status" do
        expect(result.status).to eq(:ok)
      end

      it "creates a HashcatStatus record" do
        expect { result }.to change(HashcatStatus, :count).by(1)
      end

      it "creates a HashcatGuess record" do
        expect { result }.to change(HashcatGuess, :count).by(1)
      end

      it "creates DeviceStatus records" do
        expect { result }.to change(DeviceStatus, :count).by(1)
      end

      it "updates task activity timestamp" do
        original_timestamp = task.activity_timestamp
        result
        expect(task.reload.activity_timestamp).not_to eq(original_timestamp)
        expect(task.reload.activity_timestamp).to be_within(5.seconds).of(Time.zone.now)
      end
    end

    context "when hashcat_guess is missing" do
      let(:status_params) { valid_status_params.except(:hashcat_guess) }

      it "returns a failed result" do
        expect(result.success?).to be false
      end

      it "returns :error status" do
        expect(result.status).to eq(:error)
      end

      it "returns guess_not_found error type" do
        expect(result.error_type).to eq(:guess_not_found)
      end

      it "includes appropriate error message" do
        expect(result.error).to eq("Guess not found")
      end
    end

    context "when device_statuses is missing" do
      let(:status_params) { valid_status_params.except(:device_statuses) }

      it "returns a failed result" do
        expect(result.success?).to be false
      end

      it "returns :error status" do
        expect(result.status).to eq(:error)
      end

      it "returns device_statuses_not_found error type" do
        expect(result.error_type).to eq(:device_statuses_not_found)
      end
    end

    context "when task is stale" do
      let(:status_params) { valid_status_params }

      before do
        task.update!(stale: true)
      end

      it "returns :stale status" do
        expect(result.status).to eq(:stale)
      end

      it "is still considered successful" do
        expect(result.success?).to be true
      end
    end

    context "when task is paused" do
      let(:status_params) { valid_status_params }

      before do
        task.pause! if task.can_pause?
      end

      it "returns :paused status" do
        expect(result.status).to eq(:paused)
      end

      it "is still considered successful" do
        expect(result.success?).to be true
      end
    end

    context "with legacy devices parameter name" do
      let(:status_params) do
        params = valid_status_params.except(:device_statuses)
        params[:devices] = valid_status_params[:device_statuses]
        params
      end

      it "accepts devices as alternative to device_statuses" do
        expect(result.success?).to be true
      end
    end
  end

  describe "Result struct" do
    it "has status attribute" do
      result = described_class::Result.new(status: :ok)
      expect(result.status).to eq(:ok)
    end

    it "has error attribute" do
      result = described_class::Result.new(error: "Test error")
      expect(result.error).to eq("Test error")
    end

    it "has error_type attribute" do
      result = described_class::Result.new(error_type: :test_type)
      expect(result.error_type).to eq(:test_type)
    end

    describe "#success?" do
      it "returns true for :ok status" do
        expect(described_class::Result.new(status: :ok).success?).to be true
      end

      it "returns true for :stale status" do
        expect(described_class::Result.new(status: :stale).success?).to be true
      end

      it "returns true for :paused status" do
        expect(described_class::Result.new(status: :paused).success?).to be true
      end

      it "returns false for :error status" do
        expect(described_class::Result.new(status: :error).success?).to be false
      end
    end
  end
end
