# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe DataCleanupJob do
  describe "#perform" do
    let(:job) { described_class.new }

    before do
      allow(ApplicationConfig).to receive_messages(agent_error_retention: 30.days, audit_retention: 90.days, hashcat_status_retention: 7.days)
    end

    describe "agent error cleanup" do
      let(:agent) { create(:agent) }

      it "deletes agent errors older than retention period" do
        old_error = create(:agent_error, agent: agent, created_at: 31.days.ago)
        recent_error = create(:agent_error, agent: agent, created_at: 1.day.ago)

        expect { job.perform }.to change(AgentError, :count).by(-1)

        expect(AgentError.exists?(old_error.id)).to be false
        expect(AgentError.exists?(recent_error.id)).to be true
      end

      it "does not delete errors within retention period" do
        create(:agent_error, agent: agent, created_at: 29.days.ago)
        create(:agent_error, agent: agent, created_at: 1.day.ago)

        expect { job.perform }.not_to change(AgentError, :count)
      end

      it "logs when errors are deleted" do
        create(:agent_error, agent: agent, created_at: 31.days.ago)

        allow(Rails.logger).to receive(:info)
        job.perform

        expect(Rails.logger).to have_received(:info).with(/Deleted 1 agent errors/)
      end

      it "handles errors gracefully" do
        allow(AgentError).to receive(:where).and_raise(StandardError.new("Database error"))
        allow(Rails.logger).to receive(:error)

        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Error cleaning agent errors/)
      end
    end

    describe "audit cleanup" do
      let(:user) { create(:user) }

      it "deletes audits older than retention period" do
        old_audit = Audited::Audit.create!(
          auditable_type: "User",
          auditable_id: user.id,
          action: "update",
          created_at: 91.days.ago
        )
        recent_audit = Audited::Audit.create!(
          auditable_type: "User",
          auditable_id: user.id,
          action: "update",
          created_at: 1.day.ago
        )

        expect { job.perform }.to change(Audited::Audit, :count).by(-1)

        expect(Audited::Audit.exists?(old_audit.id)).to be false
        expect(Audited::Audit.exists?(recent_audit.id)).to be true
      end

      it "logs when audits are deleted" do
        Audited::Audit.create!(
          auditable_type: "User",
          auditable_id: user.id,
          action: "update",
          created_at: 91.days.ago
        )

        allow(Rails.logger).to receive(:info)
        job.perform

        expect(Rails.logger).to have_received(:info).with(/Deleted 1 audit records/)
      end
    end

    describe "HashcatStatus cleanup" do
      let(:completed_task) { create(:task, state: "completed") }
      let(:running_task) { create(:task, state: "running") }

      it "deletes old HashcatStatus for completed tasks" do
        old_status = create(:hashcat_status, task: completed_task, created_at: 8.days.ago)
        recent_status = create(:hashcat_status, task: completed_task, created_at: 1.day.ago)

        expect { job.perform }.to change(HashcatStatus, :count).by(-1)

        expect(HashcatStatus.exists?(old_status.id)).to be false
        expect(HashcatStatus.exists?(recent_status.id)).to be true
      end

      it "does not delete HashcatStatus for running tasks" do
        create(:hashcat_status, task: running_task, created_at: 8.days.ago)

        expect { job.perform }.not_to change(HashcatStatus, :count)
      end

      it "deletes old HashcatStatus for exhausted tasks" do
        exhausted_task = create(:task, state: "exhausted")
        old_status = create(:hashcat_status, task: exhausted_task, created_at: 8.days.ago)

        expect { job.perform }.to change(HashcatStatus, :count).by(-1)
        expect(HashcatStatus.exists?(old_status.id)).to be false
      end

      it "deletes old HashcatStatus for failed tasks" do
        failed_task = create(:task, state: "failed")
        old_status = create(:hashcat_status, task: failed_task, created_at: 8.days.ago)

        expect { job.perform }.to change(HashcatStatus, :count).by(-1)
        expect(HashcatStatus.exists?(old_status.id)).to be false
      end

      it "logs when statuses are deleted" do
        create(:hashcat_status, task: completed_task, created_at: 8.days.ago)

        allow(Rails.logger).to receive(:info)
        job.perform

        expect(Rails.logger).to have_received(:info).with(/Deleted 1 HashcatStatus records/)
      end
    end

    it "is enqueued in the low queue" do
      expect(described_class.new.queue_name).to eq("low")
    end

    describe "failure tracking" do
      it "reports a summary when cleanup operations fail" do
        allow(AgentError).to receive(:where).and_raise(StandardError.new("DB error"))
        allow(Rails.logger).to receive(:error)

        job.perform

        expect(Rails.logger).to have_received(:error).with(/Cleanup completed with 1 failure.*agent_errors/)
      end

      it "includes backtrace in error logs" do
        allow(AgentError).to receive(:where).and_raise(StandardError.new("DB error"))
        allow(Rails.logger).to receive(:error)

        job.perform

        expect(Rails.logger).to have_received(:error).with(/Backtrace:/).at_least(:once)
      end
    end
  end
end
