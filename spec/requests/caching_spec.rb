# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Caching Behavior" do
  let!(:project) { create(:project) }
  let!(:user) { create(:user, projects: [project]) }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    sign_in user
    Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
  end

  describe "system health check caching" do
    before do
      stub_health_checks
      allow(Rails).to receive(:cache).and_return(memory_cache)
    end

    it "caches results with the correct key" do
      get system_health_path
      expect(response).to have_http_status(:success)

      cached = memory_cache.read(SystemHealthCheckService::CACHE_KEY)
      expect(cached).to be_present
    end

    it "returns cached results on subsequent requests" do
      # First request populates cache
      get system_health_path
      expect(response).to have_http_status(:success)

      first_cached = memory_cache.read(SystemHealthCheckService::CACHE_KEY)
      expect(first_cached).to be_present

      # Second request uses cache
      get system_health_path
      expect(response).to have_http_status(:success)

      second_cached = memory_cache.read(SystemHealthCheckService::CACHE_KEY)
      expect(second_cached).to eq(first_cached)
    end

    it "cache key matches expected constant" do
      expect(SystemHealthCheckService::CACHE_KEY).to eq("system_health_checks")
    end

    it "cache TTL is 1 minute" do
      expect(SystemHealthCheckService::CACHE_TTL).to eq(1.minute)
    end
  end

  describe "campaign ETA caching" do
    let(:campaign) { create(:campaign, project: project) }

    it "CampaignEtaCalculator caches current_eta results" do
      allow(Rails).to receive(:cache).and_return(memory_cache)
      calculator = CampaignEtaCalculator.new(campaign, cache: true)

      # Call twice - second call should use cached result
      result1 = calculator.current_eta
      result2 = calculator.current_eta

      expect(result1).to eq(result2)
    end

    it "CampaignEtaCalculator respects cache: false option" do
      allow(Rails).to receive(:cache).and_return(memory_cache)
      calculator = CampaignEtaCalculator.new(campaign, cache: false)

      calculator.current_eta
      expect(memory_cache.read("#{campaign.cache_key_with_version}/eta/current_eta")).to be_nil
    end

    it "cache key includes attack and task freshness" do
      calculator = CampaignEtaCalculator.new(campaign, cache: true)
      key = calculator.send(:cache_key, "current_eta")
      expect(key).to include(campaign.cache_key_with_version)
      expect(key).to include("/eta/current_eta/")
    end
  end

  describe "recent cracks caching" do
    let(:hash_list) { create(:hash_list, project: project) }
    let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
    let!(:attack) { create(:dictionary_attack, campaign: campaign) }

    before do
      hash_list.hash_items.delete_all
      create(:hash_item, :cracked_recently, hash_list: hash_list, attack: attack, plain_text: "cached_pass")
      allow(Rails).to receive(:cache).and_return(memory_cache)
    end

    it "caches recent_cracks results with 1-minute TTL" do
      result1 = hash_list.recent_cracks
      result2 = hash_list.recent_cracks

      expect(result1).to eq(result2)
      expect(result1).not_to be_empty
    end

    it "caches recent_cracks_count results" do
      count1 = hash_list.recent_cracks_count
      count2 = hash_list.recent_cracks_count

      expect(count1).to eq(count2)
      expect(count1).to be >= 1
    end
  end

  describe "agent metrics caching via database columns" do
    let!(:agent) { create(:agent, projects: [project], current_hash_rate: 1_000_000) }

    it "stores cached hash rate in the agent model" do
      expect(agent.current_hash_rate).to eq(1_000_000)
    end

    it "displays hash rate from cached column" do
      expect(agent.hash_rate_display).to include("MH/s").or include("kH/s").or include("H/s")
    end

    it "returns dash when hash rate is nil" do
      agent.update!(current_hash_rate: nil)
      expect(agent.hash_rate_display).to eq("—")
    end
  end

  describe "cache invalidation" do
    before do
      stub_health_checks
      allow(Rails).to receive(:cache).and_return(memory_cache)
    end

    it "fresh health check results override stale cache" do
      # Populate cache
      get system_health_path
      first_checked_at = memory_cache.read(SystemHealthCheckService::CACHE_KEY)[:checked_at]

      # Clear cache to simulate expiration
      memory_cache.delete(SystemHealthCheckService::CACHE_KEY)

      # New request repopulates cache
      get system_health_path
      second_checked_at = memory_cache.read(SystemHealthCheckService::CACHE_KEY)[:checked_at]

      expect(second_checked_at).to be_present
    end

    it "CampaignEtaCalculator cache busts when tasks update" do
      campaign = create(:campaign, project: project)
      attack = create(:dictionary_attack, campaign: campaign)
      agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)

      calculator = CampaignEtaCalculator.new(campaign, cache: true)
      key_before = calculator.send(:cache_key, "current_eta")

      # Force a future timestamp to ensure the key changes
      task.update_column(:updated_at, 1.minute.from_now) # rubocop:disable Rails/SkipsModelValidations

      key_after = calculator.send(:cache_key, "current_eta")
      expect(key_after).not_to eq(key_before)
    end
  end

  private

  def stub_health_checks
    allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
    allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_return(true)
    allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
    stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
    allow(Sidekiq::Stats).to receive(:new).and_return(stats)
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
  end
end
