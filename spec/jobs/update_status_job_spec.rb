# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe UpdateStatusJob do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  ActiveJob::Base.queue_adapter = :test
  let(:project) { create(:project) }
  let(:agent) { create(:agent, projects: [project]) }
  let(:attack) { create(:dictionary_attack) }

  describe "queuing" do
    subject(:job) { described_class.perform_later }

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "queues the job" do
      expect { job }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
    end

    it "is in high priority queue" do
      expect(described_class.new.queue_name).to eq("high")
    end

    it "executes the queued job" do
      expect { job }.to have_enqueued_job(described_class)
      perform_enqueued_jobs { job }
    end
  end

  describe "#perform" do
    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    context "when agent hasn't been seen for more than #{ApplicationConfig.agent_considered_offline_time} seconds" do
      let(:too_old) { ApplicationConfig.agent_considered_offline_time + 1.minute }
      let(:not_too_old) { ApplicationConfig.agent_considered_offline_time - 1.minute }
      let!(:offline_agent) { create(:agent, last_seen_at: too_old.ago, state: "pending") }
      let!(:online_agent) { create(:agent, last_seen_at: not_too_old.ago, state: "pending") }

      it "checks the online status of the offline agent" do
        described_class.new.perform
        expect { offline_agent.reload }.to change(offline_agent, :state).from("pending").to("offline")
      end

      it "does not check the online status of the online agent" do
        described_class.new.perform
        expect { online_agent.reload }.not_to change(online_agent, :state).from("pending")
      end
    end

    context "when the task has been running for more than #{ApplicationConfig.task_considered_abandoned_age} seconds" do
      let(:too_old) { ApplicationConfig.task_considered_abandoned_age + 1.minute }
      let(:not_too_old) { ApplicationConfig.task_considered_abandoned_age - 1.minute }

      let(:running_task) { create(:task, state: "running", activity_timestamp: too_old.ago, attack:, agent:) }
      let(:not_running_task) { create(:task, state: "running", activity_timestamp: not_too_old.ago, attack:, agent:) }

      it "abandons the task" do
        expect { described_class.new.perform }.to change { Task.exists?(running_task.id) }.from(true).to(false)
      end

      it "does not abandon the task" do
        expect { described_class.new.perform }.not_to change { Task.exists?(not_running_task.id) }
      end
    end

    context "when the task has hashcat statuses" do
      let(:running_task) {
        create(:task, state: :running, attack:, agent:,
                      hashcat_statuses: build_list(:hashcat_status, 50))
      }

      let(:exhausted_task) {
        create(:task, state: :exhausted, attack:, agent:,
                      hashcat_statuses: build_list(:hashcat_status, 50))
      }

      let(:pending_task) {
        create(:task, state: :pending, attack:, agent:,
                      hashcat_statuses: build_list(:hashcat_status, 50))
      }

      let(:completed_task) {
        create(:task, state: :completed, attack:, agent:,
                      hashcat_statuses: build_list(:hashcat_status, 50))
      }

      it "trims the hashcat statuses of the running task to #{ApplicationConfig.task_status_limit}" do
        expect { described_class.new.perform }.to change { running_task.hashcat_statuses.count }.from(50).to(ApplicationConfig.task_status_limit)
      end

      it "removes the hashcat statuses of the exhausted task" do
        expect { described_class.new.perform }.to change { exhausted_task.hashcat_statuses.count }.from(50).to(0)
      end

      it "trims the hashcat statuses of the pending task to #{ApplicationConfig.task_status_limit}" do
        expect { described_class.new.perform }.to change { pending_task.hashcat_statuses.count }.from(50).to(10)
      end

      it "does remove the hashcat statuses of the completed task" do
        expect { described_class.new.perform }.to change { completed_task.hashcat_statuses.count }.from(50).to(0)
      end
    end

    context "when managing campaign priorities" do
      it "completes successfully with no active campaigns" do
        campaign = create(:campaign)
        create(:dictionary_attack, campaign: campaign, state: "completed")

        expect { described_class.new.perform }.not_to raise_error
      end

      it "completes successfully with no campaigns at all" do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context "when cleaning up old agent errors" do
      let(:agent) { create(:agent) }

      it "removes agent errors older than the retention period" do
        old_error = travel_to(31.days.ago) { create(:agent_error, agent: agent) }
        recent_error = create(:agent_error, agent: agent)

        described_class.new.perform

        expect(AgentError.unscoped.exists?(old_error.id)).to be false
        expect(AgentError.unscoped.exists?(recent_error.id)).to be true
      end

      it "handles cleanup errors gracefully" do
        allow(AgentError).to receive(:remove_old_errors).and_raise(StandardError.new("Cleanup failed"))
        allow(Rails.logger).to receive(:error)

        expect { described_class.new.perform }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Error cleaning up old agent errors/)
      end
    end

    context "when rebalancing task assignments for high-priority campaigns" do
      let!(:project) { create(:project) }
      let!(:agents) { create_list(:agent, 2, state: :active) }

      it "triggers preemption for pending high-priority attacks with no running tasks" do
        high_campaign = create(:campaign, project: project, priority: :high)
        normal_campaign = create(:campaign, project: project, priority: :normal)

        # Create running tasks from normal-priority campaign to fill capacity (both agents)
        normal_attack_1 = create(:dictionary_attack, campaign: normal_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_campaign)
        running_task_1 = create(:task, attack: normal_attack_1, agent: agents[0], state: :running)
        running_task_2 = create(:task, attack: normal_attack_2, agent: agents[1], state: :running)
        create(:hashcat_status, task: running_task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: running_task_2, progress: [50, 100], status: :running)

        # Create high-priority attack with no running tasks but remaining work
        high_attack = create(:dictionary_attack, campaign: high_campaign)
        create(:hash_item, hash_list: high_campaign.hash_list, plain_text: nil)

        # Before running the job, verify the task is running
        expect(running_task_1.reload.state).to eq("running")

        # Run the job
        described_class.new.perform

        # After running, task should be preempted (pending) and stale
        expect(running_task_1.reload.state).to eq("pending")
        expect(running_task_1.reload.stale).to be true
      end

      it "does not preempt when nodes are available" do
        high_campaign = create(:campaign, project: project, priority: :high)
        normal_campaign = create(:campaign, project: project, priority: :normal)

        normal_attack = create(:dictionary_attack, campaign: normal_campaign)
        running_task = create(:task, attack: normal_attack, agent: agents[0], state: :running)

        # Create high-priority attack (second node is available)
        high_attack = create(:dictionary_attack, campaign: high_campaign)

        expect {
          described_class.new.perform
        }.not_to change { running_task.reload.state }
      end

      it "does not preempt for deferred-priority attacks" do
        deferred_campaign = create(:campaign, project: project, priority: :deferred)
        normal_campaign = create(:campaign, project: project, priority: :normal)

        normal_attack = create(:dictionary_attack, campaign: normal_campaign)
        running_task_1 = create(:task, attack: normal_attack, agent: agents[0], state: :running)
        create(:hashcat_status, task: running_task_1, progress: [25, 100], status: :running)

        # Fill second node
        normal_attack_2 = create(:dictionary_attack, campaign: normal_campaign)
        running_task_2 = create(:task, attack: normal_attack_2, agent: agents[1], state: :running)

        # Create deferred attack (should not trigger preemption)
        deferred_attack = create(:dictionary_attack, campaign: deferred_campaign)

        expect {
          described_class.new.perform
        }.not_to change { running_task_1.reload.state }
      end

      it "handles individual preemption errors gracefully" do
        high_campaign = create(:campaign, project: project, priority: :high)
        normal_campaign = create(:campaign, project: project, priority: :normal)

        # Fill both nodes
        normal_attack_1 = create(:dictionary_attack, campaign: normal_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_campaign)
        running_task_1 = create(:task, attack: normal_attack_1, agent: agents[0], state: :running)
        running_task_2 = create(:task, attack: normal_attack_2, agent: agents[1], state: :running)
        create(:hashcat_status, task: running_task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: running_task_2, progress: [50, 100], status: :running)

        # Create high-priority attack with uncracked hashes
        high_attack = create(:dictionary_attack, campaign: high_campaign)
        create(:hash_item, hash_list: high_campaign.hash_list, plain_text: nil)

        # Simulate error for preemption
        service_double = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).and_return(service_double)
        allow(service_double).to receive(:preempt_if_needed)
          .and_raise(StandardError.new("Preemption failed"))

        allow(Rails.logger).to receive(:error)

        # Should not raise error and should log
        expect { described_class.new.perform }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Error preempting tasks for attack/)
      end

      it "handles database errors in query gracefully" do
        high_campaign = create(:campaign, project: project, priority: :high)

        # Simulate database error
        allow(Attack).to receive(:incomplete).and_raise(ActiveRecord::StatementInvalid.new("Database connection lost"))
        allow(Rails.logger).to receive(:error)

        expect { described_class.new.perform }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Error in rebalance_task_assignments/)
      end

      it "logs errors with backtrace for debugging" do
        high_campaign = create(:campaign, project: project, priority: :high)

        allow(Attack).to receive(:incomplete).and_raise(StandardError.new("Test error"))
        allow(Rails.logger).to receive(:error)

        described_class.new.perform

        expect(Rails.logger).to have_received(:error).with(/Backtrace:/)
      end

      it "avoids N+1 queries when checking multiple high-priority attacks" do
        # Create 3 high-priority attacks to detect N+1 queries
        3.times do
          campaign = create(:campaign, project: project, priority: :high)
          attack = create(:dictionary_attack, campaign: campaign)
          create(:hash_item, hash_list: campaign.hash_list, plain_text: nil)
        end

        # Track queries - without includes, this would generate N queries for campaign and hash_list
        queries = []
        query_counter = lambda do |_name, _started, _finished, _unique_id, payload|
          queries << payload[:sql] if payload[:name] == "SQL" && payload[:sql] !~ /^(BEGIN|COMMIT|SAVEPOINT|RELEASE)/
        end

        ActiveSupport::Notifications.subscribed(query_counter, "sql.active_record") do
          described_class.new.send(:rebalance_task_assignments)
        end

        # Should only have:
        # 1. Query to load attacks with includes (campaign and hash_list)
        # 2. Query to check for running tasks
        # Without includes, there would be 3 queries per attack (1 for campaign, 1 for hash_list for each attack.uncracked_count call)
        # With 3 attacks, that would be 9+ queries. With includes, should be ~2-3 queries total.
        expect(queries.count).to be <= 5
      end
    end
  end
end
