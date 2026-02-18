# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe CampaignEtaCalculator do
  subject(:calculator) { described_class.new(campaign, cache: false) }

  let(:campaign) { create(:campaign) }

  describe "#current_eta" do
    context "with no running attacks" do
      it "returns nil" do
        expect(calculator.current_eta).to be_nil
      end
    end

    context "with running attacks but no running tasks" do
      before do
        create(:dictionary_attack, :running, campaign: campaign)
      end

      it "returns nil" do
        expect(calculator.current_eta).to be_nil
      end
    end

    context "with running attacks and tasks" do
      let(:attack) { create(:dictionary_attack, :running, campaign: campaign) }
      let(:expected_eta) { 1.hour.from_now }

      before do
        task = create(:task, attack: attack, state: :running)
        allow(task).to receive(:estimated_finish_time).and_return(expected_eta)
        allow(Task).to receive(:where).and_call_original
        # rubocop:disable RSpec/MessageChain
        allow(Task).to receive_message_chain(:joins, :where, :with_state).and_return([task])
        # rubocop:enable RSpec/MessageChain
      end

      it "returns the maximum task ETA" do
        expect(calculator.current_eta).to be_within(1.second).of(expected_eta)
      end
    end

    context "with multiple running tasks" do
      let(:attack) { create(:dictionary_attack, :running, campaign: campaign) }
      let(:earlier_eta) { 30.minutes.from_now }
      let(:later_eta) { 2.hours.from_now }

      before do
        earlier_task = create(:task, attack: attack, state: :running)
        later_task = create(:task, attack: attack, state: :running)
        allow(earlier_task).to receive(:estimated_finish_time).and_return(earlier_eta)
        allow(later_task).to receive(:estimated_finish_time).and_return(later_eta)
        # rubocop:disable RSpec/MessageChain
        allow(Task).to receive_message_chain(:joins, :where, :with_state).and_return([earlier_task, later_task])
        # rubocop:enable RSpec/MessageChain
      end

      it "returns the maximum ETA among all tasks" do
        expect(calculator.current_eta).to be_within(1.second).of(later_eta)
      end
    end
  end

  describe "#total_eta" do
    context "with no incomplete attacks" do
      before do
        create(:dictionary_attack, :completed, campaign: campaign)
      end

      it "returns nil" do
        expect(calculator.total_eta).to be_nil
      end
    end

    context "with only running attacks" do
      before do
        attack = create(:dictionary_attack, :running, campaign: campaign)
        create(:task, attack: attack, state: :running)
      end

      it "returns nil since running attacks are not considered incomplete" do
        # Running attacks are excluded from the incomplete scope
        # Use current_eta for running work ETA
        expect(calculator.total_eta).to be_nil
      end
    end

    context "with pending attacks and benchmarks" do
      let(:benchmark) { instance_double(HashcatBenchmark, hash_speed: 100_000) }

      before do
        attack = create(:dictionary_attack, campaign: campaign)
        # Bypass after_create_commit callback that recalculates complexity
        # rubocop:disable Rails/SkipsModelValidations
        attack.update_column(:complexity_value, 1_000_000)
        # rubocop:enable Rails/SkipsModelValidations
        allow(HashcatBenchmark).to receive(:fastest_device_for_hash_type).and_return(benchmark)
      end

      it "estimates completion based on complexity and hash rate" do
        # 1_000_000 / 100_000 = 10 seconds
        result = calculator.total_eta
        expect(result).to be_within(2.seconds).of(10.seconds.from_now)
      end
    end

    context "with pending attacks and no benchmarks" do
      before do
        attack = create(:dictionary_attack, campaign: campaign)
        # Bypass after_create_commit callback that recalculates complexity
        # rubocop:disable Rails/SkipsModelValidations
        attack.update_column(:complexity_value, 1_000_000)
        # rubocop:enable Rails/SkipsModelValidations
        allow(HashcatBenchmark).to receive(:fastest_device_for_hash_type).and_return(nil)
      end

      it "returns nil when no hash rate available" do
        expect(calculator.total_eta).to be_nil
      end
    end
  end

  describe "caching" do
    subject(:cached_calculator) { described_class.new(campaign, cache: true) }

    it "caches current_eta results when cache is enabled" do
      allow(Rails.cache).to receive(:fetch).and_call_original

      cached_calculator.current_eta

      expect(Rails.cache).to have_received(:fetch)
        .with(/eta\/current_eta/, expires_in: 1.minute)
    end

    it "caches total_eta results when cache is enabled" do
      allow(Rails.cache).to receive(:fetch).and_call_original

      cached_calculator.total_eta

      expect(Rails.cache).to have_received(:fetch)
        .with(/eta\/total_eta/, expires_in: 1.minute)
    end

    it "does not cache when cache is disabled" do
      allow(Rails.cache).to receive(:fetch).and_call_original

      calculator.current_eta

      expect(Rails.cache).not_to have_received(:fetch)
    end
  end
end
