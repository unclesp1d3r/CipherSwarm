# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hashcat_statuses
#
#  id                                                       :bigint           not null, primary key, indexed => [task_id, created_at]
#  estimated_stop(The estimated time of completion)         :datetime
#  original_line(The original line from the hashcat output) :text
#  progress(The progress in percentage)                     :bigint           is an Array
#  recovered_hashes(The number of recovered hashes)         :bigint           is an Array
#  recovered_salts(The number of recovered salts)           :bigint           is an Array
#  rejected(The number of rejected hashes)                  :bigint
#  restore_point(The restore point)                         :bigint
#  session(The session name)                                :string           not null
#  status(The status code)                                  :integer          not null, indexed => [task_id, time]
#  target(The target file)                                  :string           not null
#  time(The time of the status)                             :datetime         not null, indexed => [task_id, status], indexed
#  time_start(The time the task started)                    :datetime         not null
#  created_at                                               :datetime         not null, indexed => [task_id, id]
#  updated_at                                               :datetime         not null
#  task_id                                                  :bigint           not null, indexed => [created_at, id], indexed, indexed => [status, time]
#
# Indexes
#
#  index_hashcat_statuses_on_task_created_id_desc  (task_id,created_at DESC,id DESC)
#  index_hashcat_statuses_on_task_id               (task_id)
#  index_hashcat_statuses_on_task_status_time      (task_id,status,time DESC)
#  index_hashcat_statuses_on_time                  (time)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe HashcatStatus do
  describe "associations" do
    it { is_expected.to belong_to(:task) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:time) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:session) }
    it { is_expected.to validate_presence_of(:target) }
    it { is_expected.to validate_presence_of(:time_start) }

    describe "array length validations" do
      let(:hashcat_status) { build(:hashcat_status) }

      it "accepts progress with exactly 2 entries" do
        hashcat_status.progress = [100, 10000]
        expect(hashcat_status).to be_valid
      end

      it "rejects progress with more than 2 entries" do
        hashcat_status.progress = [100, 10000, 999]
        expect(hashcat_status).not_to be_valid
        expect(hashcat_status.errors[:progress]).to include("must have exactly 2 entries")
      end

      it "rejects progress with only 1 entry" do
        hashcat_status.progress = [100]
        expect(hashcat_status).not_to be_valid
        expect(hashcat_status.errors[:progress]).to include("must have exactly 2 entries")
      end

      it "accepts nil progress" do
        hashcat_status.progress = nil
        expect(hashcat_status).to be_valid
      end

      it "rejects recovered_hashes with more than 2 entries" do
        hashcat_status.recovered_hashes = [1, 2, 3]
        expect(hashcat_status).not_to be_valid
        expect(hashcat_status.errors[:recovered_hashes]).to include("must have exactly 2 entries")
      end

      it "rejects recovered_hashes with only 1 entry" do
        hashcat_status.recovered_hashes = [1]
        expect(hashcat_status).not_to be_valid
        expect(hashcat_status.errors[:recovered_hashes]).to include("must have exactly 2 entries")
      end

      it "rejects recovered_salts with more than 2 entries" do
        hashcat_status.recovered_salts = [1, 2, 3]
        expect(hashcat_status).not_to be_valid
        expect(hashcat_status.errors[:recovered_salts]).to include("must have exactly 2 entries")
      end

      it "rejects recovered_salts with only 1 entry" do
        hashcat_status.recovered_salts = [1]
        expect(hashcat_status).not_to be_valid
        expect(hashcat_status.errors[:recovered_salts]).to include("must have exactly 2 entries")
      end

      it "rejects more than 64 device_statuses" do
        hashcat_status.save!
        hashcat_status.device_statuses.clear

        65.times { |i| hashcat_status.device_statuses.build(device_id: i, device_name: "GPU #{i}", device_type: "GPU", speed: 1000, utilization: 50, temperature: 60) }
        expect(hashcat_status).not_to be_valid
        expect(hashcat_status.errors[:device_statuses]).to include("must have at most 64 entries")
      end

      it "accepts up to 64 device_statuses" do
        hashcat_status.save!
        hashcat_status.device_statuses.clear

        64.times { |i| hashcat_status.device_statuses.build(device_id: i, device_name: "GPU #{i}", device_type: "GPU", speed: 1000, utilization: 50, temperature: 60) }
        expect(hashcat_status).to be_valid
      end
    end
  end

  describe "scopes" do
    describe ".latest" do
      let(:task) { create(:task) }
      let!(:hashcat_status_1day) { create(:hashcat_status, task: task, time: 1.day.ago) }
      let(:hashcat_status_2day) { create(:hashcat_status, task: task, time: 2.days.ago) }
      let(:hashcat_status_3day) { create(:hashcat_status, task: task, time: 3.days.ago) }

      it "returns the latest hashcat status" do
        expect(described_class.latest).to eq(hashcat_status_1day)
      end
    end
  end

  describe "enums" do
    let(:hashcat_status) { create(:hashcat_status) }

    it {
      expect(hashcat_status).to define_enum_for(:status)
                                  .with_values({
                                    initializing: 0,
                                    autotuning: 1,
                                    self_testing: 2,
                                    running: 3,
                                    paused: 4,
                                    exhausted: 5,
                                    cracked: 6,
                                    aborted: 7,
                                    quit: 8,
                                    bypassed: 9,
                                    aborted_session_checkpoint: 10,
                                    aborted_runtime_limit: 11,
                                    error: 13,
                                    aborted_finish: 14,
                                    autodetecting: 16
                                  })
    }
  end

  describe "methods" do
    describe "#status_text" do
      let(:hashcat_status) { create(:hashcat_status, status: :running) }

      it "returns the status text" do
        expect(hashcat_status.status_text).to eq("Running")
      end
    end

    describe "#update_agent_metrics callback" do
      let(:task) { create(:task) }
      let(:agent) { task.agent }
      let(:fast_device_status) { create(:device_status, speed: 1000, temperature: 65, utilization: 80) }
      let(:faster_device_status) { create(:device_status, speed: 1500, temperature: 70, utilization: 90) }

      it "updates agent metrics when status is :running" do
        hashcat_status = build(:hashcat_status, task: task, status: :running)
        hashcat_status.device_statuses << fast_device_status
        hashcat_status.device_statuses << faster_device_status
        hashcat_status.save!

        agent.reload
        expect(agent.current_hash_rate).to eq(2500)
        expect(agent.current_temperature).to eq(70)
        expect(agent.current_utilization).to eq(85)
        expect(agent.metrics_updated_at).not_to be_nil
      end

      it "does not update agent metrics when status is not :running" do
        hashcat_status = build(:hashcat_status, task: task, status: :paused)
        hashcat_status.device_statuses << fast_device_status
        hashcat_status.save!

        agent.reload
        expect(agent.current_hash_rate).to be_zero
        expect(agent.metrics_updated_at).to be_nil
      end

      it "throttles updates when metrics were updated less than 30 seconds ago" do
        # Create first status and update metrics
        hashcat_status_1 = build(:hashcat_status, task: task, status: :running)
        hashcat_status_1.device_statuses << fast_device_status
        hashcat_status_1.save!

        first_metrics_updated_at = agent.reload.metrics_updated_at

        # Create second status immediately (within 30 seconds)
        hashcat_status_2 = build(:hashcat_status, task: task, status: :running)
        hashcat_status_2.device_statuses << faster_device_status
        hashcat_status_2.save!

        # Metrics should not be updated
        expect(agent.reload.metrics_updated_at).to eq(first_metrics_updated_at)
      end

      it "rescues and logs errors without failing the status creation" do
        # Create a status that would trigger the callback
        hashcat_status = build(:hashcat_status, task: task, status: :running)
        hashcat_status.device_statuses << fast_device_status

        # Mock the agent's update_columns to raise an error with backtrace
        error = StandardError.new("Database error")
        error.set_backtrace(["line1", "line2"])
        allow(agent).to receive(:update_columns).and_raise(error)

        # Setup logger as a spy to verify error logging
        allow(Rails.logger).to receive(:error)

        # The callback should rescue the error and not raise it
        expect { hashcat_status.save! }.not_to raise_error

        # Verify the error was logged with backtrace
        expect(Rails.logger).to have_received(:error).with(/Failed to update agent metrics for task #{task.id}/)
      end

      it "handles errors with nil backtrace" do
        hashcat_status = build(:hashcat_status, task: task, status: :running)
        hashcat_status.device_statuses << fast_device_status

        # Raise an error without backtrace (nil backtrace)
        error = StandardError.new("Database error")
        allow(error).to receive(:backtrace).and_return(nil)
        allow(agent).to receive(:update_columns).and_raise(error)
        allow(Rails.logger).to receive(:error)

        expect { hashcat_status.save! }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Failed to update agent metrics/)
      end

      it "rescues broadcast errors separately from metrics errors" do
        hashcat_status = build(:hashcat_status, task: task, status: :running)
        hashcat_status.device_statuses << fast_device_status

        allow(agent).to receive(:broadcast_replace_later_to).and_raise(StandardError.new("Redis down"))
        allow(Rails.logger).to receive(:error)

        expect { hashcat_status.save! }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Failed to broadcast agent metrics for task #{task.id}/)
      end
    end
  end

  describe "factory" do
    it "is valid" do
      expect(build(:hashcat_status)).to be_valid
    end
  end

  describe ".trim_excess_for_incomplete_tasks" do
    # The SQL orders by `time DESC, id DESC` to determine which statuses to keep.
    # All tests use explicit, well-spaced `time` values to avoid nondeterminism
    # from the factory's random Faker::Time generation or tied sort keys.
    let(:running_task) do
      task = create(:task)
      task.accept!
      task
    end

    let(:base_time) { Time.zone.parse("2026-01-01 12:00:00") }

    it "trims statuses beyond the limit for incomplete tasks" do
      15.times do |i|
        create(:hashcat_status, task: running_task, time: base_time + i.minutes)
      end

      expect { described_class.trim_excess_for_incomplete_tasks(limit: 10) }
        .to change { described_class.where(task: running_task).count }.from(15).to(10)
    end

    it "keeps the most recent statuses by time" do
      oldest  = create(:hashcat_status, task: running_task, time: base_time)
      middle  = create(:hashcat_status, task: running_task, time: base_time + 30.minutes)
      newest  = create(:hashcat_status, task: running_task, time: base_time + 1.hour)

      described_class.trim_excess_for_incomplete_tasks(limit: 2)

      expect(described_class.exists?(newest.id)).to be true
      expect(described_class.exists?(middle.id)).to be true
      expect(described_class.exists?(oldest.id)).to be false
    end

    it "breaks ties on equal time values by keeping the higher id" do
      earlier_id = create(:hashcat_status, task: running_task, time: base_time)
      later_id   = create(:hashcat_status, task: running_task, time: base_time)

      described_class.trim_excess_for_incomplete_tasks(limit: 1)

      expect(described_class.exists?(later_id.id)).to be true
      expect(described_class.exists?(earlier_id.id)).to be false
    end

    it "does not trim statuses for finished tasks" do
      task = create(:task)
      task.accept!
      task.complete!
      5.times do |i|
        create(:hashcat_status, task: task, time: base_time + i.minutes)
      end

      expect { described_class.trim_excess_for_incomplete_tasks(limit: 2) }
        .not_to(change { described_class.where(task: task).count })
    end

    it "cascades deletes to device_statuses via FK" do
      3.times do |i|
        create(:hashcat_status, task: running_task, time: base_time + i.minutes)
      end

      # Factory creates 2 device_statuses per hashcat_status (6 total).
      # Trimming to 1 deletes 2 statuses and their 4 device_statuses via FK CASCADE.
      expect { described_class.trim_excess_for_incomplete_tasks(limit: 1) }
        .to change(DeviceStatus, :count).by(-4)
    end

    it "returns 0 for invalid limit" do
      expect(described_class.trim_excess_for_incomplete_tasks(limit: nil)).to eq(0)
      expect(described_class.trim_excess_for_incomplete_tasks(limit: -1)).to eq(0)
    end
  end
end
