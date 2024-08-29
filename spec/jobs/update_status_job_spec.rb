# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateStatusJob do
  include ActiveJob::TestHelper

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
      too_old = ApplicationConfig.agent_considered_offline_time + 1.minute
      not_too_old = ApplicationConfig.agent_considered_offline_time - 1.minute
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
      too_old = ApplicationConfig.task_considered_abandoned_age + 1.minute
      not_too_old = ApplicationConfig.task_considered_abandoned_age - 1.minute

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
  end
end
