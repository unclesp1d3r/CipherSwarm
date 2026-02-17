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

    it "agent list query count does not grow linearly with agent count", :aggregate_failures do
      5.times { create(:agent, projects: [project]) }

      # Warm up
      get agents_path

      query_count_5 = 0
      counter = ->(*_args) { query_count_5 += 1 }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get agents_path
      end
      expect(response).to have_http_status(:success)

      # Add more agents
      15.times { create(:agent, projects: [project]) }

      query_count_20 = 0
      counter_20 = ->(*_args) { query_count_20 += 1 }
      ActiveSupport::Notifications.subscribed(counter_20, "sql.active_record") do
        get agents_path
      end
      expect(response).to have_http_status(:success)

      # Query count should not grow proportionally (N+1 would make it ~4x)
      expect(query_count_20).to be < (query_count_5 * 3)
    end

    it "campaign list query count does not grow linearly with campaign count", :aggregate_failures do
      5.times { create(:campaign, project: project) }

      # Warm up
      get campaigns_path

      query_count_5 = 0
      counter = ->(*_args) { query_count_5 += 1 }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get campaigns_path
      end
      expect(response).to have_http_status(:success)

      # Add more campaigns
      15.times { create(:campaign, project: project) }

      query_count_20 = 0
      counter_20 = ->(*_args) { query_count_20 += 1 }
      ActiveSupport::Notifications.subscribed(counter_20, "sql.active_record") do
        get campaigns_path
      end
      expect(response).to have_http_status(:success)

      # Query count should not grow proportionally (N+1 would make it ~4x)
      expect(query_count_20).to be < (query_count_5 * 3)
    end

    it "campaign show with attacks does not exceed reasonable query count" do
      campaign = create(:campaign, project: project)
      create_list(:dictionary_attack, 10, campaign: campaign)

      query_count = 0
      counter = ->(*_args) { query_count += 1 }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get campaign_path(campaign)
      end

      expect(response).to have_http_status(:success)
      # Should not have excessive queries even with 10 attacks
      expect(query_count).to be < 80
    end
  end

  describe "database index verification" do
    it "tasks table has index on agent_id and state for task queries" do
      indexes = ActiveRecord::Base.connection.indexes(:tasks).map(&:columns)
      expect(indexes).to include(["agent_id"])
      expect(indexes).to include(["agent_id", "state"])
      expect(indexes).to include(["attack_id"])
      expect(indexes).to include(["state"])
    end

    it "attacks table has index on campaign_id and state" do
      indexes = ActiveRecord::Base.connection.indexes(:attacks).map(&:columns)
      expect(indexes).to include(["campaign_id"])
      expect(indexes).to include(["campaign_id", "state"])
      expect(indexes).to include(["state"])
    end

    it "agents table has index on state for fleet queries" do
      indexes = ActiveRecord::Base.connection.indexes(:agents).map(&:columns)
      expect(indexes).to include(["state"])
      expect(indexes).to include(["state", "last_seen_at"])
    end

    it "hash_items table has index on hash_list_id for crack lookups" do
      indexes = ActiveRecord::Base.connection.indexes(:hash_items).map(&:columns)
      expect(indexes).to include(["hash_list_id"])
      expect(indexes).to include(["cracked_time"])
    end

    it "hashcat_statuses table has index on task_id for status queries" do
      indexes = ActiveRecord::Base.connection.indexes(:hashcat_statuses).map(&:columns)
      expect(indexes).to include(["task_id"])
    end

    it "agent_errors table has index on agent_id for error queries" do
      indexes = ActiveRecord::Base.connection.indexes(:agent_errors).map(&:columns)
      expect(indexes).to include(["agent_id"])
      expect(indexes).to include(["task_id"])
    end

    it "task show query uses index on tasks primary key (EXPLAIN check)" do
      campaign = create(:campaign, project: project)
      attack = create(:dictionary_attack, campaign: campaign)
      agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)

      # Use exec_query to avoid interference with any message expectations on execute
      result = ActiveRecord::Base.connection.exec_query(
        "EXPLAIN SELECT * FROM tasks WHERE id = #{task.id}"
      )
      plan = result.rows.flatten.join(" ")

      # Should use an index scan, not a sequential scan
      expect(plan).to match(/Index Scan|Index Only Scan|Bitmap/)
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
