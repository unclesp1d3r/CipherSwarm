# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe TaskAssignmentService do
  subject(:service) { described_class.new(agent) }

  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:hash_type) { HashType.find_by(hashcat_mode: 0) || create(:md5) }
  let(:hash_list) { create(:hash_list, hash_type: hash_type, project: project) }
  let(:campaign) { create(:campaign, hash_list: hash_list, project: project) }
  let(:agent) { create(:agent, user: user, projects: [project]) }

  before do
    # Create benchmark so agent supports hash type 0 (MD5)
    create(:hashcat_benchmark, agent: agent, hash_type: 0, hash_speed: 10_000_000)
  end

  describe "#find_next_task" do
    context "when agent has no projects" do
      let(:agent) { create(:agent, user: user, projects: []) }

      it "returns nil" do
        expect(service.find_next_task).to be_nil
      end
    end

    context "when agent has an incomplete task without fatal errors" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:task) { create(:task, agent: agent, attack: attack, state: :running) }

      before do
        # Ensure hash_list has uncracked items
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns the existing incomplete task" do
        expect(service.find_next_task).to eq(task)
      end
    end

    context "when agent has an incomplete task with a fatal error" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:task) { create(:task, agent: agent, attack: attack, state: :running) }

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
        create(:agent_error, agent: agent, task: task, severity: :fatal)
      end

      it "does not return the task with fatal error" do
        expect(service.find_next_task).not_to eq(task)
      end
    end

    context "when there is a pending task from an attack" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :pending) }
      let!(:pending_task) { create(:task, agent: agent, attack: attack, state: :pending) }

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns the pending task" do
        expect(service.find_next_task).to eq(pending_task)
      end
    end

    context "when there is a failed task that can be retried" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:failed_task) { create(:task, agent: agent, attack: attack, state: :failed) }

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns the failed task for retry" do
        expect(service.find_next_task).to eq(failed_task)
      end
    end

    context "when there is a failed task with fatal error" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:failed_task) { create(:task, agent: agent, attack: attack, state: :failed) }

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
        create(:agent_error, agent: agent, task: failed_task, severity: :fatal)
      end

      it "does not return the failed task with fatal error" do
        result = service.find_next_task
        expect(result).not_to eq(failed_task)
      end
    end

    context "when there are no pending tasks and agent meets performance threshold" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :pending) }

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "creates and returns a new task" do
        expect { service.find_next_task }.to change(Task, :count).by(1)
      end

      it "associates the new task with the attack" do
        task = service.find_next_task
        expect(task.attack).to eq(attack)
      end

      it "associates the new task with the agent" do
        task = service.find_next_task
        expect(task.agent).to eq(agent)
      end
    end

    context "when agent does not meet performance threshold" do
      let(:attack) { create(:dictionary_attack, campaign: campaign, state: :pending) }

      before do
        attack # ensure attack is created
        create(:hash_item, hash_list: hash_list, cracked: false)
        # Set benchmark with hash_speed below the min_performance_benchmark (1000)
        agent.hashcat_benchmarks.find_each { |b| b.update!(hash_speed: 500) }
      end

      it "does not create a new task" do
        expect { service.find_next_task }.not_to change(Task, :count)
      end

      it "logs an info-level agent error" do
        expect { service.find_next_task }.to change(AgentError, :count).by(1)
      end

      it "creates error with correct severity" do
        service.find_next_task
        error = agent.agent_errors.last
        expect(error.severity).to eq("info")
      end

      it "creates error with correct message" do
        service.find_next_task
        error = agent.agent_errors.last
        expect(error.message).to include("performance threshold")
      end
    end

    context "when attack has no uncracked hashes" do
      let(:attack) { create(:dictionary_attack, campaign: campaign, state: :pending) }

      before do
        attack # ensure attack is created
        hash_list.hash_items.delete_all
        # All hashes are cracked
        create(:hash_item, hash_list: hash_list, cracked: true)
      end

      it "returns nil" do
        expect(service.find_next_task).to be_nil
      end
    end

    context "when agent does not support the hash type" do
      let(:unsupported_hash_type) { create(:hash_type, hashcat_mode: 9999, name: "Unsupported") }
      let(:unsupported_hash_list) { create(:hash_list, hash_type: unsupported_hash_type, project: project) }
      let(:unsupported_campaign) { create(:campaign, hash_list: unsupported_hash_list, project: project) }
      let(:attack) { create(:dictionary_attack, campaign: unsupported_campaign, state: :pending) }

      before do
        attack # ensure attack is created
        create(:hash_item, hash_list: unsupported_hash_list, cracked: false)
      end

      it "returns nil" do
        expect(service.find_next_task).to be_nil
      end
    end

    context "when attack is in a different project" do
      let(:other_project) { create(:project) }
      let(:other_hash_list) { create(:hash_list, hash_type: hash_type, project: other_project) }
      let(:other_campaign) { create(:campaign, hash_list: other_hash_list, project: other_project) }
      let(:attack) { create(:dictionary_attack, campaign: other_campaign, state: :pending) }

      before do
        attack # ensure attack is created
        create(:hash_item, hash_list: other_hash_list, cracked: false)
      end

      it "returns nil" do
        expect(service.find_next_task).to be_nil
      end
    end

    context "when multiple attacks exist" do
      let(:complex_attack) do
        attack = create(:dictionary_attack, campaign: campaign, state: :pending)
        # rubocop:disable Rails/SkipsModelValidations
        attack.update_column(:complexity_value, 1000)
        # rubocop:enable Rails/SkipsModelValidations
        attack
      end
      let(:simple_attack) do
        attack = create(:dictionary_attack, campaign: campaign, state: :pending)
        # rubocop:disable Rails/SkipsModelValidations
        attack.update_column(:complexity_value, 100)
        # rubocop:enable Rails/SkipsModelValidations
        attack
      end

      before do
        complex_attack # ensure attacks are created in order
        simple_attack
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "prioritizes attacks with lower complexity" do
        task = service.find_next_task
        expect(task.attack).to eq(simple_attack)
      end
    end
  end

  describe "#find_next_task cross-agent isolation" do
    let(:other_agent) { create(:agent, user: user, projects: [project]) }

    before do
      create(:hashcat_benchmark, agent: other_agent, hash_type: 0, hash_speed: 10_000_000)
    end

    context "when another agent has a failed task for the same attack" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }

      before do
        create(:task, agent: other_agent, attack: attack, state: :failed)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "does not return a task belonging to another agent" do
        expect(service.find_next_task&.agent).not_to eq(other_agent)
      end
    end

    context "when another agent has a pending task for the same attack" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :pending) }

      before do
        create(:task, agent: other_agent, attack: attack, state: :pending)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "does not return a task belonging to another agent" do
        expect(service.find_next_task&.agent).not_to eq(other_agent)
      end
    end

    context "when agent has its own failed task alongside another agent's failed task" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:own_failed_task) { create(:task, agent: agent, attack: attack, state: :failed) }

      before do
        create(:task, agent: other_agent, attack: attack, state: :failed)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns only the agent's own failed task" do
        expect(service.find_next_task).to eq(own_failed_task)
      end
    end

    context "when agent has its own pending task alongside another agent's pending task" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :pending) }
      let!(:own_pending_task) { create(:task, agent: agent, attack: attack, state: :pending) }

      before do
        create(:task, agent: other_agent, attack: attack, state: :pending)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns only the agent's own pending task" do
        expect(service.find_next_task).to eq(own_pending_task)
      end
    end
  end

  describe "#find_next_task integration" do
    it "handles multiple consecutive calls correctly" do
      create(:hash_item, hash_list: hash_list, cracked: false)
      create(:dictionary_attack, campaign: campaign, state: :pending)

      # Multiple calls should work consistently
      first_task = service.find_next_task
      expect(first_task).to be_present

      # Second call returns the same task (incomplete task takes priority)
      second_task = service.find_next_task
      expect(second_task).to eq(first_task)
    end
  end

  describe "#find_unassigned_paused_task" do
    let(:offline_agent) { create(:agent, user: user, projects: [project], state: :offline) }

    before do
      create(:hashcat_benchmark, agent: offline_agent, hash_type: 0, hash_speed: 10_000_000)
    end

    context "when a paused task from an offline agent exists in agent's project" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:paused_task) do
        create(:task, agent: offline_agent, attack: attack, state: :paused)
      end

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns the orphaned task after resuming it to pending" do
        result = service.send(:find_unassigned_paused_task)
        expect(result).to eq(paused_task)
        expect(result.state).to eq("pending")
      end

      it "reassigns agent_id to the claiming agent" do
        service.send(:find_unassigned_paused_task)
        expect(paused_task.reload.agent_id).to eq(agent.id)
      end

      it "marks the task as stale so the new agent re-downloads cracks" do
        service.send(:find_unassigned_paused_task)
        expect(paused_task.reload.stale).to be true
      end
    end

    context "when no orphaned paused tasks exist" do
      before do
        create(:dictionary_attack, campaign: campaign, state: :running)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns nil" do
        expect(service.send(:find_unassigned_paused_task)).to be_nil
      end
    end

    context "when paused task belongs to an active agent" do
      before do
        active_agent = create(:agent, user: user, projects: [project], state: :active)
        attack = create(:dictionary_attack, campaign: campaign, state: :running)
        create(:task, agent: active_agent, attack: attack, state: :paused)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns nil" do
        expect(service.send(:find_unassigned_paused_task)).to be_nil
      end
    end

    context "when paused task is in a different project" do
      before do
        other_project = create(:project)
        other_hash_list = create(:hash_list, hash_type: hash_type, project: other_project)
        other_campaign = create(:campaign, hash_list: other_hash_list, project: other_project)
        attack = create(:dictionary_attack, campaign: other_campaign, state: :running)
        other_offline_agent = create(:agent, user: user, projects: [other_project], state: :offline)
        create(:task, agent: other_offline_agent, attack: attack, state: :paused)
        create(:hash_item, hash_list: other_hash_list, cracked: false)
      end

      it "returns nil" do
        expect(service.send(:find_unassigned_paused_task)).to be_nil
      end
    end

    context "when paused task has no uncracked hashes" do
      before do
        attack = create(:dictionary_attack, campaign: campaign, state: :running)
        create(:task, agent: offline_agent, attack: attack, state: :paused)
        # Mark ALL hash_items as cracked (including any auto-created by ProcessHashListJob)
        # to ensure no uncracked hashes remain for the EXISTS subquery
        HashItem.where(hash_list_id: hash_list.id).update_all(cracked: true) # rubocop:disable Rails/SkipsModelValidations
      end

      it "returns nil" do
        expect(service.send(:find_unassigned_paused_task)).to be_nil
      end
    end
  end

  describe "agent shutdown reassignment integration" do
    let(:other_agent) { create(:agent, user: user, projects: [project]) }
    let(:other_service) { described_class.new(other_agent) }

    before do
      create(:hashcat_benchmark, agent: other_agent, hash_type: 0, hash_speed: 10_000_000)
    end

    context "when an agent shuts down with a running task" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:running_task) { create(:task, agent: agent, attack: attack, state: :running) }

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
        allow(Rails.logger).to receive(:info)
        agent.shutdown
      end

      it "makes the paused task discoverable by another agent in pending state" do
        task = other_service.find_next_task
        expect(task).to eq(running_task.reload)
        expect(task.state).to eq("pending")
      end

      it "keeps agent_id populated after shutdown" do
        expect(running_task.reload.agent_id).to eq(agent.id)
      end

      it "reassigns agent_id to the claiming agent on pickup" do
        other_service.find_next_task
        expect(running_task.reload.agent_id).to eq(other_agent.id)
      end
    end
  end

  describe "#should_attempt_preemption?" do
    let(:attack) { create(:dictionary_attack, campaign: campaign) }

    context "when attack has nil campaign" do
      it "returns false without raising error" do
        allow(attack).to receive(:campaign).and_return(nil)
        expect(service.send(:should_attempt_preemption?, attack)).to be false
      end
    end

    context "when attack.campaign.priority is nil" do
      it "returns false without raising error" do
        allow(campaign).to receive(:priority).and_return(nil)
        expect(service.send(:should_attempt_preemption?, attack)).to be false
      end
    end

    context "when attack.campaign raises an error" do
      it "returns false without raising error" do
        allow(attack).to receive(:campaign).and_raise(ActiveRecord::RecordNotFound)
        expect(service.send(:should_attempt_preemption?, attack)).to be false
      end
    end

    context "when attack.campaign.priority raises an error" do
      it "returns false without raising error" do
        allow(attack.campaign).to receive(:priority).and_raise(StandardError)
        expect(service.send(:should_attempt_preemption?, attack)).to be false
      end
    end

    context "when campaign priority is high" do
      before { campaign.update!(priority: :high) }

      it "returns true" do
        expect(service.send(:should_attempt_preemption?, attack)).to be true
      end
    end

    context "when campaign priority is deferred" do
      before { campaign.update!(priority: :deferred) }

      it "returns false" do
        expect(service.send(:should_attempt_preemption?, attack)).to be false
      end
    end
  end

  describe "#find_task_from_available_attacks with preemption" do
    let(:high_priority_campaign) { create(:campaign, hash_list: hash_list, project: project, priority: :high) }
    let(:deferred_priority_campaign) { create(:campaign, hash_list: hash_list, project: project, priority: :deferred) }

    before do
      create(:hash_item, hash_list: hash_list, cracked: false)
    end

    context "when high-priority attack needs assignment and all nodes are busy" do
      let(:high_attack) { create(:dictionary_attack, campaign: high_priority_campaign, state: :pending) }

      # rubocop:disable RSpec/SubjectStub
      it "calls preemption service and retries task assignment after successful preemption" do
        # Create a new task that will be returned after preemption
        new_task = create(:task, agent: agent, attack: high_attack, state: :pending)

        # Stub find_or_create_task_for_attack to return nil first (no task available)
        # Then return the new task after preemption succeeds
        call_count = 0
        allow(service).to receive(:find_or_create_task_for_attack) do |_attack|
          call_count += 1
          call_count == 1 ? nil : new_task
        end

        # Stub should_attempt_preemption? to return true
        allow(service).to receive(:should_attempt_preemption?).and_return(true)

        # Stub TaskPreemptionService to simulate successful preemption
        preemption_service = instance_double(TaskPreemptionService)
        preempted_task = instance_double(Task)
        allow(TaskPreemptionService).to receive(:new).and_return(preemption_service)
        allow(preemption_service).to receive(:preempt_if_needed).and_return(preempted_task)

        # Call find_task_from_available_attacks
        task = service.send(:find_task_from_available_attacks)

        # Should call preemption and return task after retry
        expect(task).to eq(new_task)
        expect(preemption_service).to have_received(:preempt_if_needed).once
      end
      # rubocop:enable RSpec/SubjectStub
    end

    context "when deferred-priority attack needs assignment and all nodes are busy" do
      let(:deferred_attack) { create(:dictionary_attack, campaign: deferred_priority_campaign, state: :pending) }

      # rubocop:disable RSpec/SubjectStub
      it "does not attempt preemption for deferred priority" do
        # Reference deferred_attack to ensure it's created
        expect(deferred_attack).to be_present

        # Stub service methods to control behavior
        allow(service).to receive_messages(
          find_or_create_task_for_attack: nil,
          should_attempt_preemption?: false
        )

        # TaskPreemptionService should not be instantiated
        allow(TaskPreemptionService).to receive(:new).and_call_original

        # Call find_task_from_available_attacks
        task = service.send(:find_task_from_available_attacks)

        # Should return nil without attempting preemption
        expect(task).to be_nil
        expect(TaskPreemptionService).not_to have_received(:new)
      end
      # rubocop:enable RSpec/SubjectStub
    end

    context "when preemption fails (no preemptable tasks)" do
      let(:high_attack) { create(:dictionary_attack, campaign: high_priority_campaign, state: :pending) }

      # rubocop:disable RSpec/SubjectStub
      it "returns nil gracefully when preemption returns nil" do
        # Reference high_attack to ensure it's created
        expect(high_attack).to be_present

        # Stub service methods to control behavior
        allow(service).to receive_messages(
          find_or_create_task_for_attack: nil,
          should_attempt_preemption?: true
        )

        # Stub TaskPreemptionService to return nil (preemption failed)
        preemption_service = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).and_return(preemption_service)
        allow(preemption_service).to receive(:preempt_if_needed).and_return(nil)

        # Call find_task_from_available_attacks
        task = service.send(:find_task_from_available_attacks)

        # Should return nil gracefully
        expect(task).to be_nil
        expect(preemption_service).to have_received(:preempt_if_needed).once
      end
      # rubocop:enable RSpec/SubjectStub
    end
  end
end
