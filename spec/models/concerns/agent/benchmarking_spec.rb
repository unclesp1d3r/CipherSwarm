# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe Agent::Benchmarking do
  let(:agent) { create(:agent) }
  let(:hash_type) { create(:hash_type) }
  let(:benchmark_date) { 1.day.ago }

  describe "#aggregate_benchmarks" do
    context "when no benchmarks exist" do
      it "returns nil" do
        expect(agent.aggregate_benchmarks).to be_nil
      end
    end

    context "when benchmarks exist" do
      let(:hash_type_2) { create(:hash_type) }

      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   hash_speed: 1_000_000, benchmark_date: benchmark_date)
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type_2.hashcat_mode,
                                   hash_speed: 2_000_000, benchmark_date: benchmark_date)
      end

      it "returns aggregated benchmark summaries" do
        result = agent.aggregate_benchmarks
        expect(result).to be_an(Array)
        expect(result).not_to be_empty
      end

      it "groups benchmarks by hash type" do
        result = agent.aggregate_benchmarks
        expect(result.length).to eq(2) # Two different hash types
      end
    end
  end

  describe "#allowed_hash_types" do
    context "when no benchmarks exist" do
      it "returns an empty array" do
        expect(agent.allowed_hash_types).to eq([])
      end
    end

    context "when benchmarks exist" do
      let(:hash_type_2) { create(:hash_type) }

      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: benchmark_date)
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type_2.hashcat_mode,
                                   benchmark_date: benchmark_date)
      end

      it "returns distinct hash types" do
        result = agent.allowed_hash_types
        expect(result).to contain_exactly(hash_type.hashcat_mode, hash_type_2.hashcat_mode)
      end
    end
  end

  describe "#benchmarks" do
    context "when no benchmarks exist" do
      it "returns nil" do
        expect(agent.benchmarks).to be_nil
      end
    end

    context "when benchmarks exist" do
      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: benchmark_date)
      end

      it "returns benchmarks as strings" do
        result = agent.benchmarks
        expect(result).to be_an(Array)
        expect(result).to all(be_a(String))
      end
    end
  end

  describe "#format_benchmark_summary" do
    context "when hash type exists in database" do
      it "formats with hash type name" do
        result = agent.format_benchmark_summary(hash_type.hashcat_mode, 1_000_000)
        expect(result).to include(hash_type.name)
        expect(result).to include("hashes/sec")
      end
    end

    context "when hash type does not exist in database" do
      it "formats with basic h/s format" do
        result = agent.format_benchmark_summary(99999, 1_000_000)
        expect(result).to include("99999")
        expect(result).to include("h/s")
      end
    end
  end

  describe "#last_benchmark_date" do
    context "when no benchmarks exist" do
      it "returns date from a year ago" do
        expected = agent.created_at - 365.days
        expect(agent.last_benchmark_date).to be_within(1.second).of(expected)
      end
    end

    context "when benchmarks exist" do
      let(:most_recent_date) { 1.day.ago }
      let(:older_date) { 1.week.ago }

      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: older_date)
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: most_recent_date)
      end

      it "returns the most recent benchmark date" do
        result = agent.last_benchmark_date
        expect(result).to be_within(1.second).of(most_recent_date)
      end
    end
  end

  describe "#last_benchmarks" do
    context "when no benchmarks exist" do
      it "returns nil" do
        expect(agent.last_benchmarks).to be_nil
      end
    end

    context "when benchmarks exist from multiple days" do
      let(:recent_date) { 1.day.ago }
      let(:older_date) { 1.week.ago }

      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: older_date)
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: recent_date)
      end

      it "returns only benchmarks from the most recent day" do
        result = agent.last_benchmarks
        expect(result.count).to eq(1)
        expect(result.first.benchmark_date).to be_within(1.second).of(recent_date)
      end
    end
  end

  describe "#meets_performance_threshold?" do
    context "when hash speed meets threshold" do
      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   hash_speed: ApplicationConfig.min_performance_benchmark + 1000,
                                   benchmark_date: benchmark_date)
      end

      it "returns true" do
        expect(agent.meets_performance_threshold?(hash_type.hashcat_mode)).to be true
      end
    end

    context "when hash speed is below threshold" do
      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   hash_speed: 1, benchmark_date: benchmark_date)
      end

      it "returns false" do
        expect(agent.meets_performance_threshold?(hash_type.hashcat_mode)).to be false
      end
    end

    context "when no benchmarks for hash type" do
      it "returns false" do
        expect(agent.meets_performance_threshold?(hash_type.hashcat_mode)).to be false
      end
    end
  end

  describe "#benchmarking?" do
    let(:pending_agent) { create(:agent, state: "pending") }

    context "when agent is pending, recently seen, and has no benchmarks" do
      before { pending_agent.update!(last_seen_at: 30.seconds.ago) }

      it "returns true" do
        expect(pending_agent.benchmarking?).to be true
      end
    end

    context "when agent is active" do
      it "returns false" do
        agent.update!(last_seen_at: 30.seconds.ago)
        expect(agent).to be_active
        expect(agent.benchmarking?).to be false
      end
    end

    context "when agent is pending but not recently seen" do
      before { pending_agent.update!(last_seen_at: 5.minutes.ago) }

      it "returns false" do
        expect(pending_agent.benchmarking?).to be false
      end
    end

    context "when agent is pending and recently seen but has benchmarks" do
      before do
        pending_agent.update!(last_seen_at: 30.seconds.ago)
        create(:hashcat_benchmark, agent: pending_agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: benchmark_date)
      end

      it "returns false" do
        expect(pending_agent.benchmarking?).to be false
      end
    end

    context "when agent has never been seen" do
      it "returns false" do
        expect(pending_agent.benchmarking?).to be false
      end
    end
  end

  describe "#needs_benchmark?" do
    context "when benchmarks are recent" do
      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: 1.day.ago)
      end

      it "returns false" do
        expect(agent.needs_benchmark?).to be false
      end
    end

    context "when benchmarks are older than max age" do
      before do
        old_date = ApplicationConfig.max_benchmark_age.ago - 1.day
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type.hashcat_mode,
                                   benchmark_date: old_date)
      end

      it "returns true" do
        expect(agent.needs_benchmark?).to be true
      end
    end

    context "when no benchmarks exist" do
      it "returns true" do
        expect(agent.needs_benchmark?).to be true
      end
    end
  end
end
