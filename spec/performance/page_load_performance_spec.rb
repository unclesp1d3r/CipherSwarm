# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Page Load Performance", type: :request do
  let!(:project) { create(:project) }
  let!(:user) { create(:user, projects: [project]) }

  before do
    sign_in user
  end

  describe "agent list performance" do
    it "loads agent list within 2 seconds with 50 agents" do
      50.times { create(:agent, projects: [project]) }

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get agents_path
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.0
    end

    it "loads agent cards endpoint within 2 seconds with 50 agents" do
      50.times { create(:agent, projects: [project]) }

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get cards_agents_path
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.0
    end
  end

  describe "campaign page performance" do
    it "loads campaign page within 2 seconds with 20 attacks" do
      campaign = create(:campaign, project: project)
      20.times { create(:dictionary_attack, campaign: campaign) } # rubocop:disable FactoryBot/CreateList

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get campaign_path(campaign)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.0
    end
  end

  describe "task show page performance" do
    it "loads task show page within 1 second" do
      campaign = create(:campaign, project: project)
      attack = create(:dictionary_attack, campaign: campaign)
      agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get task_path(task)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 1.0
    end

    it "loads task logs page within 2 seconds with 55 statuses" do
      campaign = create(:campaign, project: project)
      attack = create(:dictionary_attack, campaign: campaign)
      agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)
      55.times do |i|
        create(:hashcat_status, task: task, time: (60 - i).minutes.ago)
      end

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get logs_task_path(task)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.0
    end
  end

  describe "system health check performance" do
    before do
      Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
      stub_health_checks
    end

    it "system health page loads within 5 seconds" do
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get system_health_path
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 5.0
    end

    it "health check timeout is configured at 5 seconds" do
      expect(SystemHealthCheckService::CHECK_TIMEOUT).to eq(5)
    end
  end

  describe "campaigns index performance" do
    it "loads campaigns index within 2 seconds with 30 campaigns" do
      30.times do
        create(:campaign, project: project)
      end

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get campaigns_path
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.0
    end
  end

  describe "database query efficiency" do
    it "task show does not exceed reasonable query count" do
      campaign = create(:campaign, project: project)
      attack = create(:dictionary_attack, campaign: campaign)
      agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)
      create_list(:hashcat_status, 5, task: task)

      query_count = 0
      counter = ->(*_args) { query_count += 1 }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get task_path(task)
      end

      expect(response).to have_http_status(:success)
      # A reasonable upper bound - should not have excessive N+1 queries
      expect(query_count).to be < 50
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
