# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe StateChangeLogger do
  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe ".log_task_transition" do
    let(:task) { instance_double(Task, id: 123, agent_id: 456, attack_id: 789) }

    it "logs the task state transition" do
      described_class.log_task_transition(
        task: task,
        event: :accept,
        transition: { from: "pending", to: "running" }
      )

      expect(Rails.logger).to have_received(:info).with(
        "[Task 123] Agent 456 - Attack 789 - State change: pending -> running (accept)"
      )
    end

    it "includes context when provided" do
      described_class.log_task_transition(
        task: task,
        event: :accept,
        transition: { from: "pending", to: "running" },
        context: { action: "accepted" }
      )

      expect(Rails.logger).to have_received(:info).with(
        "[Task 123] Agent 456 - Attack 789 - State change: pending -> running (accept) - action=accepted"
      )
    end

    it "formats multiple context values" do
      described_class.log_task_transition(
        task: task,
        event: :accept,
        transition: { from: "pending", to: "running" },
        context: { action: "accepted", reason: "manual" }
      )

      expect(Rails.logger).to have_received(:info).with(
        match(/action=accepted reason=manual/)
      )
    end
  end

  describe ".log_agent_lifecycle" do
    let(:agent) { instance_double(Agent, id: 123) }

    it "logs the agent lifecycle event" do
      described_class.log_agent_lifecycle(
        agent: agent,
        event: :activate,
        transition: { from: "pending", to: "active" }
      )

      expect(Rails.logger).to have_received(:info).with(
        "[AgentLifecycle] activate: agent_id=123 state_change=pending->active"
      )
    end

    it "includes context when provided" do
      described_class.log_agent_lifecycle(
        agent: agent,
        event: :activate,
        transition: { from: "pending", to: "active" },
        context: { host_name: "agent1" }
      )

      expect(Rails.logger).to have_received(:info).with(
        "[AgentLifecycle] activate: agent_id=123 state_change=pending->active host_name=agent1"
      )
    end
  end

  describe ".log_attack_transition" do
    let(:attack) { instance_double(Attack, id: 123) }

    it "logs the attack state transition" do
      described_class.log_attack_transition(
        attack: attack,
        event: :run,
        transition: { from: "pending", to: "running" }
      )

      expect(Rails.logger).to have_received(:info).with(
        "[AttackLifecycle] run: attack_id=123 state_change=pending->running"
      )
    end

    it "includes context when provided" do
      described_class.log_attack_transition(
        attack: attack,
        event: :run,
        transition: { from: "pending", to: "running" },
        context: { campaign_id: 456 }
      )

      expect(Rails.logger).to have_received(:info).with(
        "[AttackLifecycle] run: attack_id=123 state_change=pending->running campaign_id=456"
      )
    end
  end

  describe ".log_campaign_event" do
    let(:campaign) { instance_double(Campaign, id: 123) }

    it "logs the campaign event" do
      described_class.log_campaign_event(
        campaign: campaign,
        event: :pause
      )

      expect(Rails.logger).to have_received(:info).with(
        "[CampaignLifecycle] pause: campaign_id=123"
      )
    end

    it "includes context when provided" do
      described_class.log_campaign_event(
        campaign: campaign,
        event: :pause,
        context: { reason: "priority_change" }
      )

      expect(Rails.logger).to have_received(:info).with(
        "[CampaignLifecycle] pause: campaign_id=123 reason=priority_change"
      )
    end
  end

  describe ".log_api_error" do
    it "logs the error with all identifiers" do
      described_class.log_api_error(
        error_code: "TASK_ACCEPT_FAILED",
        ids: { agent_id: 123, task_id: 456, attack_id: 789 },
        errors: ["Invalid state"]
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/\[APIError\] TASK_ACCEPT_FAILED - Agent 123 - Task 456 - Attack 789 - Errors: Invalid state - /)
      )
    end

    it "handles missing optional identifiers" do
      described_class.log_api_error(
        error_code: "AUTH_FAILED",
        errors: ["Token expired"]
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/\[APIError\] AUTH_FAILED - Errors: Token expired/)
      )
    end

    it "handles array of errors" do
      described_class.log_api_error(
        error_code: "MULTI_ERROR",
        errors: ["Error 1", "Error 2"]
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/Errors: Error 1, Error 2/)
      )
    end

    it "includes context when provided" do
      described_class.log_api_error(
        error_code: "TEST_ERROR",
        context: { request_id: "abc123" }
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/request_id=abc123/)
      )
    end
  end

  describe ".log_data_cleanup" do
    it "logs cleanup with positive count" do
      cutoff = 30.days.ago

      described_class.log_data_cleanup(
        resource_type: "hashcat_statuses",
        deleted_count: 100,
        cutoff: cutoff
      )

      expect(Rails.logger).to have_received(:info).with(
        "[DataCleanup] Deleted 100 hashcat_statuses older than #{cutoff}"
      )
    end

    it "does not log when deleted count is zero" do
      described_class.log_data_cleanup(
        resource_type: "hashcat_statuses",
        deleted_count: 0,
        cutoff: 30.days.ago
      )

      expect(Rails.logger).not_to have_received(:info)
    end

    it "does not log when deleted count is negative" do
      described_class.log_data_cleanup(
        resource_type: "hashcat_statuses",
        deleted_count: -1,
        cutoff: 30.days.ago
      )

      expect(Rails.logger).not_to have_received(:info)
    end
  end

  describe ".log_broadcast_error" do
    let(:error) { StandardError.new("Connection refused") }

    before do
      error.set_backtrace([
        "/app/models/task.rb:50:in `broadcast'",
        "/app/models/concerns/safe_broadcasting.rb:10:in `safe_broadcast'",
        "/app/controllers/api/v1/client/tasks_controller.rb:100:in `update'",
        "/gems/actionpack/lib/action_controller/metal.rb:200:in `dispatch'",
        "/gems/actionpack/lib/action_controller/metal.rb:250:in `process'",
        "/gems/rails/lib/rails.rb:100:in `call'"
      ])
    end

    it "logs the broadcast error with model info" do
      described_class.log_broadcast_error(
        model_name: "Task",
        record_id: 123,
        error: error
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/\[BroadcastError\] Model: Task - Record ID: 123/)
      )
    end

    it "includes error message" do
      described_class.log_broadcast_error(
        model_name: "Task",
        record_id: 123,
        error: error
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/Error: Connection refused/)
      )
    end

    it "includes truncated backtrace (first 5 lines)" do
      described_class.log_broadcast_error(
        model_name: "Task",
        record_id: 123,
        error: error
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/Backtrace:.*task\.rb:50/)
      )
    end

    it "handles error without backtrace" do
      error_without_backtrace = StandardError.new("No backtrace")

      described_class.log_broadcast_error(
        model_name: "Task",
        record_id: 123,
        error: error_without_backtrace
      )

      expect(Rails.logger).to have_received(:error).with(
        match(/Backtrace: Not available/)
      )
    end
  end
end
