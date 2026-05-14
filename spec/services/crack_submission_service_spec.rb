# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe CrackSubmissionService do
  let(:project) { create(:project) }
  let(:hash_type) { create(:hash_type) }
  let(:hash_list) { create(:hash_list, project: project, hash_type: hash_type, processed: true) }
  let(:campaign) { create(:campaign, hash_list: hash_list, project: project) }
  let(:attack) { create(:attack, campaign: campaign) }
  let(:agent) { create(:agent) }
  let(:task) { create(:task, attack: attack, agent: agent, state: "running") }
  let!(:hash_item) { create(:hash_item, hash_list: hash_list, hash_value: "test_hash_value", cracked: false) }
  let(:timestamp) { Time.current }

  describe "#call" do
    subject(:result) do
      described_class.new(
        task: task,
        hash_value: hash_value,
        plain_text: plain_text,
        timestamp: timestamp
      ).call
    end

    let(:hash_value) { "test_hash_value" }
    let(:plain_text) { "cracked_password" }

    context "when the hash is found and crack succeeds" do
      it "returns a successful result" do
        expect(result.success?).to be true
      end

      it "updates the hash item as cracked" do
        result
        expect(hash_item.reload.cracked).to be true
      end

      it "sets the plain text on the hash item" do
        result
        expect(hash_item.reload.plain_text).to eq("cracked_password")
      end

      it "sets the cracked time" do
        result
        expect(hash_item.reload.cracked_time).to be_present
      end

      it "associates the attack with the hash item" do
        result
        expect(hash_item.reload.attack).to eq(attack)
      end

      it "returns the uncracked count" do
        expect(result.uncracked_count).to be_a(Integer)
      end
    end

    context "when the hash is not found" do
      let(:hash_value) { "nonexistent_hash" }

      it "returns a failed result" do
        expect(result.success?).to be false
      end

      it "returns not_found error type" do
        expect(result.error_type).to eq(:not_found)
      end

      it "returns appropriate error message" do
        expect(result.error).to eq("Hash not found")
      end
    end

    context "when there are matching hashes in other lists" do
      let(:other_hash_list) { create(:hash_list, project: project, hash_type: hash_type, processed: true) }
      let!(:matching_hash) do
        create(:hash_item, hash_list: other_hash_list, hash_value: "test_hash_value", cracked: false)
      end

      it "propagates the crack to matching hashes" do
        result
        expect(matching_hash.reload.cracked).to be true
        expect(matching_hash.reload.plain_text).to eq("cracked_password")
      end
    end

    context "when there are other tasks for the same hash list" do
      let!(:other_task) { create(:task, attack: attack, agent: agent, state: "running", stale: false) }

      it "marks other tasks as stale" do
        result
        expect(other_task.reload.stale).to be true
      end

      it "does not mark the current task as stale" do
        result
        expect(task.reload.stale).to be false
      end
    end
  end

  describe "final-crack completion with a warmed uncracked_count cache" do
    let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(Rails).to receive(:cache).and_return(memory_cache)
    end

    it "still transitions the task to completed and returns uncracked_count: 0" do
      # Warm the cache before submitting the final crack — without the
      # uncached read path, this would leave the task running.
      expect(hash_list.uncracked_count).to eq(1)

      result = described_class.new(
        task: task,
        hash_value: "test_hash_value",
        plain_text: "final_password",
        timestamp: Time.current
      ).call

      expect(result.success?).to be true
      expect(result.uncracked_count).to eq(0)
      expect(task.reload.state).to eq("completed")
    end
  end

  describe "final-crack completion when same-list duplicate exists" do
    # Regression: if accept_crack runs before propagate_crack_to_matching_hashes,
    # the completion guard sees the same-hash_list duplicate as still-uncracked
    # and leaves the task in `running`. Propagating first lets the guard read
    # the post-propagate count.
    let!(:duplicate_hash_item) do
      create(:hash_item,
             hash_list: hash_list,
             hash_value: "test_hash_value",
             hash_value_digest: Digest::MD5.hexdigest("test_hash_value"),
             cracked: false)
    end

    it "marks the duplicate cracked and transitions the task to completed in one submission" do
      result = described_class.new(
        task: task,
        hash_value: "test_hash_value",
        plain_text: "shared_password",
        timestamp: Time.current
      ).call

      expect(result.success?).to be true
      expect(duplicate_hash_item.reload.cracked).to be true
      expect(task.reload.state).to eq("completed")
    end
  end

  describe "Result struct" do
    it "has success? attribute" do
      result = described_class::Result.new(success?: true)
      expect(result.success?).to be true
    end

    it "has error attribute" do
      result = described_class::Result.new(error: "Test error")
      expect(result.error).to eq("Test error")
    end

    it "has error_type attribute" do
      result = described_class::Result.new(error_type: :not_found)
      expect(result.error_type).to eq(:not_found)
    end

    it "has uncracked_count attribute" do
      result = described_class::Result.new(uncracked_count: 42)
      expect(result.uncracked_count).to eq(42)
    end
  end
end
