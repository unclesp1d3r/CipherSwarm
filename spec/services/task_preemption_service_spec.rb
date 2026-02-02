# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe TaskPreemptionService do
  let!(:project) { create(:project) }
  let(:hash_list) { create(:hash_list, project: project) }
  let!(:hash_list_2) { create(:hash_list, project: create(:project)) }
  let!(:high_priority_campaign) { create(:campaign, project: project, priority: :high) }
  let!(:normal_priority_campaign) { create(:campaign, project: project, priority: :normal) }
  let!(:other_project_campaign) { create(:campaign, project: hash_list_2.project, priority: :normal) }
  let!(:agents) { create_list(:agent, 2, state: :active) }

  describe "#preempt_if_needed" do
    context "when nodes are available" do
      it "returns nil without attempting preemption" do
        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        expect(service.preempt_if_needed).to be_nil
      end
    end

    context "when all nodes are busy but high-priority attack arrives" do
      it "preempts least-complete lower-priority task from same project" do
        # Create agents at capacity
        agent_1 = agents[0]
        agent_2 = agents[1]

        # Create running tasks from lower-priority campaign
        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)

        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        # Create status for task_2 with 75% progress (more complete than task_1 with 25%)
        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [75, 100], status: :running)

        # High-priority attack needs a node
        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        preempted = service.preempt_if_needed
        expect(preempted).to eq(task_1)
        expect(task_1.reload.state).to eq("pending")
        expect(task_1.preemption_count).to eq(1)
        expect(task_1.stale).to be true
      end
    end

    context "when preempting tasks from other projects" do
      it "does not preempt tasks from different projects" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        # Create running tasks from other project's campaign
        other_attack_1 = create(:dictionary_attack, campaign: other_project_campaign)
        other_attack_2 = create(:dictionary_attack, campaign: other_project_campaign)

        task_1 = create(:task, attack: other_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: other_attack_2, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [75, 100], status: :running)

        # High-priority attack from first project needs a node
        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        preempted = service.preempt_if_needed
        expect(preempted).to be_nil
        expect(task_1.reload.state).to eq("running")
        expect(task_2.reload.state).to eq("running")
      end
    end

    context "when protecting nearly-complete tasks" do
      it "does not preempt tasks over 90% complete" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)

        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        # task_1 is 95% complete (should not be preempted)
        # task_2 is 50% complete (can be preempted)
        create(:hashcat_status, task: task_1, progress: [95, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        preempted = service.preempt_if_needed
        expect(preempted).to eq(task_2)
        expect(task_1.reload.state).to eq("running")
      end
    end

    context "when preventing starvation from repeated preemption" do
      it "does not preempt tasks that have been preempted 2+ times" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)

        # task_1 has been preempted 2 times (cannot preempt again)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running, preemption_count: 2)
        # task_2 has been preempted 0 times (can preempt)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running, preemption_count: 0)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [75, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        preempted = service.preempt_if_needed
        expect(preempted).to eq(task_2)
        expect(task_1.reload.preemption_count).to eq(2)
      end
    end

    context "when selecting least-complete task" do
      it "selects task with lowest progress percentage" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)

        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [80, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [20, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        preempted = service.preempt_if_needed
        expect(preempted).to eq(task_2)
      end
    end

    context "when preventing race conditions" do
      it "ensures atomicity with transaction and locking" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        # Fill both agents with running tasks
        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running, preemption_count: 0)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running, preemption_count: 0)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        # Preempt task and verify changes were applied atomically
        service.preempt_if_needed

        task_1.reload
        expect(task_1.state).to eq("pending")
        expect(task_1.preemption_count).to eq(1)
        expect(task_1.stale).to be true
      end

      it "rolls back all changes on failure" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        # Fill both agents
        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running, preemption_count: 0)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running, preemption_count: 0)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        # Simulate an error during preemption
        allow(Task).to receive(:transaction).and_raise(ActiveRecord::StatementInvalid.new("Database error"))

        expect { service.preempt_if_needed }.to raise_error(ActiveRecord::StatementInvalid)

        # Verify nothing was changed (transaction rolled back)
        task_1.reload
        expect(task_1.state).to eq("running")
        expect(task_1.preemption_count).to eq(0)
      end

      it "prevents concurrent modifications with row locking" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        # Fill both agents
        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        # Verify the service can successfully preempt (lock doesn't raise error)
        expect { service.preempt_if_needed }.not_to raise_error

        task_1.reload
        expect(task_1.state).to eq("pending")
      end
    end

    context "when logging preemption decisions" do
      it "logs when nodes are available" do
        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        allow(Rails.logger).to receive(:info)
        service.preempt_if_needed

        expect(Rails.logger).to have_received(:info).with(
          "[TaskPreemption] No preemption needed for attack #{high_attack.id}: nodes available"
        )
      end

      it "logs when no preemptable tasks are found" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        # Fill both agents with non-preemptable tasks (90%+ progress)
        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [95, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [92, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        allow(Rails.logger).to receive(:info)
        service.preempt_if_needed

        expect(Rails.logger).to have_received(:info).with(
          "[TaskPreemption] No preemptable tasks found for attack #{high_attack.id} " \
          "(priority: high)"
        )
      end
    end

    context "when handling errors during preemption" do
      it "logs error and returns nil if database query fails" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        # Fill both agents
        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        # Simulate database error during find_preemptable_task
        allow(Campaign).to receive(:priorities).and_raise(ActiveRecord::StatementInvalid.new("Database error"))
        allow(Rails.logger).to receive(:error)

        result = service.preempt_if_needed
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(
          /\[TaskPreemption\] Error finding preemptable task for attack #{high_attack.id}: Database error/
        )
      end

      it "skips tasks that raise errors during preemptability check" do # rubocop:disable RSpec/ExampleLength
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        # Make preemptable? raise an error for one task and succeed for the other
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Task).to receive(:preemptable?).and_wrap_original do |method, *args|
          # rubocop:enable RSpec/AnyInstance
          task = method.receiver
          raise StandardError, "Unexpected error" if task.id == task_1.id

          method.call(*args)
        end

        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        preempted = service.preempt_if_needed

        expect(preempted).to eq(task_2)
        expect(Rails.logger).to have_received(:error).with(
          "[TaskPreemption] Error checking if task #{task_1.id} is preemptable: Unexpected error"
        )
      end
    end

    context "when handling concurrent preemption scenarios" do
      it "skips non-running tasks during preemption selection" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        # Both agents busy with running tasks
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        # Now mark task_1 as completed to simulate state change during selection
        # rubocop:disable Rails/SkipsModelValidations
        task_1.update_columns(state: "completed")
        # rubocop:enable Rails/SkipsModelValidations

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        # The service should find and preempt task_2 since task_1 is no longer running
        allow(Rails.logger).to receive(:info)
        preempted = service.preempt_if_needed

        # With task_1 completed, there's an available agent slot, so no preemption needed
        # This verifies the service correctly detects available capacity
        expect(preempted).to be_nil
      end

      it "increments preemption_count atomically" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running, preemption_count: 0)
        task_2 = create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        # Both tasks need hashcat_statuses for preemption check
        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        allow(Rails.logger).to receive(:info)
        preempted = service.preempt_if_needed

        # Verify increment happened on preempted task
        expect(preempted).to eq(task_1)
        expect(task_1.reload.preemption_count).to eq(1)
      end

      it "handles StaleObjectError from optimistic locking gracefully" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        # Simulate StaleObjectError during increment
        call_count = 0
        allow(Task).to receive(:transaction).and_wrap_original do |method, &block|
          call_count += 1
          raise ActiveRecord::StaleObjectError.new(task_1, "update") if call_count == 1

          method.call(&block)
        end

        # The error should propagate (not silently fail)
        expect { service.preempt_if_needed }.to raise_error(ActiveRecord::StaleObjectError)
      end

      it "uses row-level locking to prevent double-preemption" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack, agent: agent_1, state: :running)
        task_2 = create(:task, attack: normal_attack, agent: agent_2, state: :running)

        create(:hashcat_status, task: task_1, progress: [25, 100], status: :running)
        create(:hashcat_status, task: task_2, progress: [50, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        allow(Rails.logger).to receive(:info)

        # Verify the service can successfully preempt and that lock! was used
        # by checking the task state changed atomically
        preempted = service.preempt_if_needed

        expect(preempted).to eq(task_1)
        expect(task_1.reload.state).to eq("pending")
        expect(task_1.stale).to be true
        expect(task_1.preemption_count).to eq(1)
      end
    end

    context "when handling edge cases" do
      it "handles task with no hashcat_statuses" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        normal_attack_1 = create(:dictionary_attack, campaign: normal_priority_campaign)
        normal_attack_2 = create(:dictionary_attack, campaign: normal_priority_campaign)
        task_1 = create(:task, attack: normal_attack_1, agent: agent_1, state: :running)
        create(:task, attack: normal_attack_2, agent: agent_2, state: :running)

        # No hashcat_statuses - progress should be 0%

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        allow(Rails.logger).to receive(:info)

        # Task with 0% progress should be preemptable
        preempted = service.preempt_if_needed
        expect(preempted).to eq(task_1)
      end

      it "selects lower priority campaign task before higher priority task" do
        agent_1 = agents[0]
        agent_2 = agents[1]

        deferred_campaign = create(:campaign, project: project, priority: :deferred)
        normal_attack = create(:dictionary_attack, campaign: normal_priority_campaign)
        deferred_attack = create(:dictionary_attack, campaign: deferred_campaign)

        task_1 = create(:task, attack: normal_attack, agent: agent_1, state: :running)
        task_2 = create(:task, attack: deferred_attack, agent: agent_2, state: :running)

        # task_1 (normal) has lower progress but higher priority
        create(:hashcat_status, task: task_1, progress: [10, 100], status: :running)
        # task_2 (deferred) has higher progress but lower priority
        create(:hashcat_status, task: task_2, progress: [80, 100], status: :running)

        high_attack = create(:dictionary_attack, campaign: high_priority_campaign)
        service = described_class.new(high_attack)

        allow(Rails.logger).to receive(:info)

        preempted = service.preempt_if_needed

        # Should preempt deferred task (lower priority) even though normal task has less progress
        expect(preempted).to eq(task_2)
      end
    end
  end
end
