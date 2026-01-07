# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hashcat_statuses
#
#  id                                                       :bigint           not null, primary key
#  estimated_stop(The estimated time of completion)         :datetime
#  original_line(The original line from the hashcat output) :text
#  progress(The progress in percentage)                     :bigint           is an Array
#  recovered_hashes(The number of recovered hashes)         :bigint           is an Array
#  recovered_salts(The number of recovered salts)           :bigint           is an Array
#  rejected(The number of rejected hashes)                  :bigint
#  restore_point(The restore point)                         :bigint
#  session(The session name)                                :string           not null
#  status(The status code)                                  :integer          not null
#  target(The target file)                                  :string           not null
#  time(The time of the status)                             :datetime         not null, indexed
#  time_start(The time the task started)                    :datetime         not null
#  created_at                                               :datetime         not null
#  updated_at                                               :datetime         not null
#  task_id                                                  :bigint           not null, indexed
#
# Indexes
#
#  index_hashcat_statuses_on_task_id  (task_id)
#  index_hashcat_statuses_on_time     (time)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe HashcatStatus do
  describe "associations" do
    it { is_expected.to belong_to(:task).touch(true) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:time) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:session) }
    it { is_expected.to validate_presence_of(:target) }
    it { is_expected.to validate_presence_of(:time_start) }
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

        # Mock the agent's update_columns to raise an error in the callback
        allow(agent).to receive(:update_columns).and_raise(StandardError.new("Database error"))

        # Setup logger as a spy to verify error logging
        allow(Rails.logger).to receive(:error)

        # The callback should rescue the error and not raise it
        expect { hashcat_status.save! }.not_to raise_error

        # Verify the error was logged
        expect(Rails.logger).to have_received(:error).with(/Failed to update agent metrics for task #{task.id}/)
      end
    end
  end

  describe "factory" do
    it "is valid" do
      expect(build(:hashcat_status)).to be_valid
    end
  end
end
