# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: tasks
#
#  id                                                                                                     :bigint           not null, primary key
#  activity_timestamp(The timestamp of the last activity on the task)                                     :datetime         indexed
#  claimed_at                                                                                             :datetime
#  expires_at                                                                                             :datetime         indexed
#  keyspace_limit(The maximum number of keyspace values to process.)                                      :integer          default(0)
#  keyspace_offset(The starting keyspace offset.)                                                         :integer          default(0)
#  last_error                                                                                             :text
#  lock_version                                                                                           :integer          default(0), not null
#  max_retries                                                                                            :integer          default(3), not null
#  preemption_count                                                                                       :integer          default(0), not null, indexed
#  retry_count                                                                                            :integer          default(0), not null
#  stale(If new cracks since the last check, the task is stale and the new cracks need to be downloaded.) :boolean          default(FALSE), not null
#  start_date(The date and time that the task was started.)                                               :datetime         not null
#  state                                                                                                  :string           default("pending"), not null, indexed => [agent_id], indexed, indexed => [claimed_by_agent_id]
#  created_at                                                                                             :datetime         not null
#  updated_at                                                                                             :datetime         not null
#  agent_id(The agent that the task is assigned to, if any.)                                              :bigint           not null, indexed, indexed => [state]
#  attack_id(The attack that the task is associated with.)                                                :bigint           not null, indexed
#  claimed_by_agent_id                                                                                    :bigint           indexed, indexed => [state]
#
# Indexes
#
#  index_tasks_on_activity_timestamp             (activity_timestamp)
#  index_tasks_on_agent_id                       (agent_id)
#  index_tasks_on_agent_id_and_state             (agent_id,state)
#  index_tasks_on_attack_id                      (attack_id)
#  index_tasks_on_claimed_by_agent_id            (claimed_by_agent_id)
#  index_tasks_on_expires_at                     (expires_at)
#  index_tasks_on_preemption_count               (preemption_count)
#  index_tasks_on_state                          (state)
#  index_tasks_on_state_and_claimed_by_agent_id  (state,claimed_by_agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (attack_id => attacks.id) ON DELETE => cascade
#  fk_rails_...  (claimed_by_agent_id => agents.id)
#
require "rails_helper"

RSpec.describe Task do
  subject { build(:task) }

  describe "associations" do
    it { is_expected.to belong_to(:attack) }
    it { is_expected.to belong_to(:agent) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:start_date) }
  end

  describe "scopes" do
    describe ".incomplete" do
      let!(:attack) { create(:dictionary_attack, name: "scope_test_attack") }
      let!(:task_completed) { create(:task, state: "completed", attack: attack) }
      let!(:task_pending) { create(:task, state: "pending", attack: attack) }
      let!(:task_running) { create(:task, state: "running", attack: attack) }
      let!(:task_exhausted) { create(:task, state: "exhausted", attack: attack) }

      it "returns tasks that are not completed" do
        expect(described_class.incomplete).to include(task_pending, task_running)
      end

      it "doesn't return incomplete tasks" do
        expect(described_class.incomplete).not_to include([task_completed, task_exhausted])
      end
    end
  end

  describe "state machine" do
    let(:task) { create(:task) }

    it "initial state is pending" do
      expect(task).to be_pending
    end

    it "transitions to running" do
      task.run
      expect(task).to be_running
    end

    it "transitions to paused" do
      task.pause
      expect(task).to be_paused
    end

    it "transitions to pending" do
      task.resume
      expect(task).to be_pending
    end

    it "transitions to completed" do
      task.complete
      expect(task).to be_completed
    end

    describe "#retry" do
      let(:failed_task) { create(:task, state: "failed") }

      it "transitions from failed to pending" do
        failed_task.retry
        expect(failed_task).to be_pending
      end

      it "increments retry_count" do
        failed_task.last_error = "Some error"
        failed_task.save

        expect(failed_task.retry_count).to eq(0)
        failed_task.retry
        failed_task.reload
        expect(failed_task.retry_count).to eq(1)
      end

      it "clears last_error" do
        failed_task.last_error = "Some error"
        failed_task.save

        expect(failed_task.last_error).not_to be_nil
        failed_task.retry
        failed_task.reload
        expect(failed_task.last_error).to be_nil
      end

      it "logs the retry event" do
        allow(Rails.logger).to receive(:info)
        failed_task.retry
        expect(Rails.logger).to have_received(:info).with(/State change:.*pending.*Task retried/)
      end
    end
  end

  describe "SafeBroadcasting integration" do
    let(:task) { create(:task) }

    it "includes SafeBroadcasting concern" do
      expect(described_class.included_modules).to include(SafeBroadcasting)
    end

    context "when broadcast fails" do
      it "logs BroadcastError without raising" do
        allow(Rails.logger).to receive(:error)
        expect { task.send(:log_broadcast_error, StandardError.new("Connection refused")) }.not_to raise_error
      end

      it "includes task ID in broadcast error log" do
        allow(Rails.logger).to receive(:error)
        task.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/Record ID: #{task.id}/).at_least(:once)
      end

      it "includes model name in broadcast error log" do
        allow(Rails.logger).to receive(:error)
        task.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/\[BroadcastError\].*Model: Task/).at_least(:once)
      end
    end
  end

  describe "#preemptable?" do
    let(:task) { create(:task) }

    context "when task is over 90% complete" do
      it "returns false" do
        create(:hashcat_status, :running, task: task, progress: [95, 100])
        expect(task.preemptable?).to be false
      end
    end

    context "when task has been preempted 2 or more times" do
      it "returns false with 2 preemptions" do
        task.update!(preemption_count: 2)
        create(:hashcat_status, :running, task: task, progress: [50, 100])
        expect(task.preemptable?).to be false
      end

      it "returns false with 3 preemptions" do
        task.update!(preemption_count: 3)
        create(:hashcat_status, :running, task: task, progress: [50, 100])
        expect(task.preemptable?).to be false
      end
    end

    context "when task is preemptable" do
      it "returns true for task under 90% complete with 0 preemptions" do
        create(:hashcat_status, :running, task: task, progress: [50, 100])
        expect(task.preemptable?).to be true
      end

      it "returns true for task under 90% complete with 1 preemption" do
        task.update!(preemption_count: 1)
        create(:hashcat_status, :running, task: task, progress: [50, 100])
        expect(task.preemptable?).to be true
      end
    end

    context "when task has no hashcat_status" do
      it "returns true" do
        expect(task.preemptable?).to be true
      end
    end

    context "with boundary conditions" do
      it "returns true at exactly 90% complete" do
        create(:hashcat_status, :running, task: task, progress: [90, 100])
        expect(task.preemptable?).to be true
      end

      it "returns false at 90.01% complete" do
        create(:hashcat_status, :running, task: task, progress: [9001, 10000])
        expect(task.preemptable?).to be false
      end

      it "returns true with exactly 1 preemption" do
        task.update!(preemption_count: 1)
        create(:hashcat_status, :running, task: task, progress: [50, 100])
        expect(task.preemptable?).to be true
      end
    end

    context "with error handling" do
      it "returns false and logs error when progress_percentage raises exception" do
        allow(Rails.logger).to receive(:error)
        allow(task).to receive(:progress_percentage).and_raise(StandardError.new("Database error"))

        expect(task.preemptable?).to be false
        expect(Rails.logger).to have_received(:error).with(/\[Task #{task.id}\].*Error calculating progress percentage/)
      end

      it "logs warning when preemption_count is nil" do
        task = create(:task, state: :running)
        allow(Rails.logger).to receive(:warn)
        allow(task).to receive(:preemption_count).and_return(nil)

        task.preemptable?
        expect(Rails.logger).to have_received(:warn).with(/preemption_count is nil/)
      end
    end
  end
end
