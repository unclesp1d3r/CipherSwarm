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

    it "is in low priority queue" do
      expect(described_class.new.queue_name).to eq("low_priority")
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

    context "when the task has been running for more than 30 minutes" do
      let(:running_task) { create(:task, state: "running", activity_timestamp: 1.hour.ago, attack:, agent:) }
      let(:not_running_task) { create(:task, state: "running", activity_timestamp: 29.minutes.ago, attack:, agent:) }

      it "abandons the task" do
        expect { described_class.new.perform }.to change { running_task.reload.state }.from("running").to("pending")
      end

      it "does not abandon the task" do
        expect { described_class.new.perform }.not_to change { not_running_task.reload.state }
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

      it "does not remove the hashcat statuses of the running task" do
        expect { described_class.new.perform }.not_to change { running_task.hashcat_statuses.count }.from(50)
      end

      it "removes the hashcat statuses of the exhausted task" do
        expect { described_class.new.perform }.to change { exhausted_task.hashcat_statuses.count }.from(50).to(10)
      end

      it "does not remove the hashcat statuses of the pending task" do
        expect { described_class.new.perform }.not_to change { pending_task.hashcat_statuses.count }.from(50)
      end

      it "does remove the hashcat statuses of the completed task" do
        expect { described_class.new.perform }.to change { completed_task.hashcat_statuses.count }.from(50).to(10)
      end
    end
  end
end
