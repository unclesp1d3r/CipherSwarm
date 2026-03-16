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

  describe "quarantined campaign exclusion" do
    let(:quarantined_campaign) { create(:campaign, hash_list: hash_list, project: project, quarantined: true, quarantine_reason: "no hashes loaded") }

    context "when agent has an incomplete task from a quarantined campaign" do
      let(:attack) { create(:dictionary_attack, campaign: quarantined_campaign, state: :running) }

      before do
        create(:task, agent: agent, attack: attack, state: :running)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "does not return the task" do
        expect(service.find_next_task).to be_nil
      end

      it "is excluded by find_existing_incomplete_task" do
        expect(service.send(:find_existing_incomplete_task)).to be_nil
      end
    end

    context "when agent has its own paused task from a quarantined campaign" do
      let(:attack) { create(:dictionary_attack, campaign: quarantined_campaign, state: :running) }

      before do
        create(:task, agent: agent, attack: attack, state: :paused, claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "does not return the paused task" do
        expect(service.send(:find_own_paused_task)).to be_nil
      end

      it "is not returned by find_next_task" do
        expect(service.find_next_task).to be_nil
      end
    end

    context "when an orphaned paused task belongs to a quarantined campaign" do
      let(:offline_agent) { create(:agent, user: user, projects: [project], state: :offline) }
      let(:attack) { create(:dictionary_attack, campaign: quarantined_campaign, state: :running) }

      before do
        create(:task, agent: offline_agent, attack: attack, state: :paused, claimed_by_agent_id: nil)
        create(:hashcat_benchmark, agent: offline_agent, hash_type: 0, hash_speed: 10_000_000)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "does not return the orphaned task" do
        expect(service.send(:find_unassigned_paused_task)).to be_nil
      end

      it "is not returned by find_next_task" do
        expect(service.find_next_task).to be_nil
      end
    end

    context "when both quarantined and non-quarantined campaigns have tasks" do
      let(:quarantined_attack) { create(:dictionary_attack, campaign: quarantined_campaign, state: :running) }
      let(:normal_attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:normal_task) { create(:task, agent: agent, attack: normal_attack, state: :running) }

      before do
        create(:task, agent: agent, attack: quarantined_attack, state: :running)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns only the task from the non-quarantined campaign" do
        expect(service.find_next_task).to eq(normal_task)
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

    context "when paused task belongs to an active agent within grace period" do
      before do
        active_agent = create(:agent, user: user, projects: [project], state: :active)
        attack = create(:dictionary_attack, campaign: campaign, state: :running)
        create(:task, agent: active_agent, attack: attack, state: :paused, paused_at: 5.minutes.ago)
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

  describe "#find_own_paused_task" do
    context "when agent has its own paused task with cleared claim fields" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:paused_task) do
        create(:task, agent: agent, attack: attack, state: :paused, claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
      end

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns the agent's own paused task" do
        result = service.send(:find_own_paused_task)
        expect(result).to eq(paused_task)
      end

      it "resumes the task to pending" do
        result = service.send(:find_own_paused_task)
        expect(result.state).to eq("pending")
      end

      it "marks the task as stale" do
        service.send(:find_own_paused_task)
        expect(paused_task.reload.stale).to be true
      end

      it "clears paused_at on resume" do
        service.send(:find_own_paused_task)
        expect(paused_task.reload.paused_at).to be_nil
      end
    end

    context "when agent has a paused task with claimed_by_agent_id still set" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
      let!(:paused_task) do
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: agent.id, paused_at: 5.minutes.ago)
      end

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "still finds the task (claim not cleared, e.g. attack cascade pause)" do
        result = service.send(:find_own_paused_task)
        expect(result).to eq(paused_task)
      end
    end

    context "when agent has a paused task and the attack is also paused (agent shutdown cascade)" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :paused) }
      let!(:paused_task) do
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
      end

      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "reclaims the task and resumes the attack" do
        result = service.send(:find_own_paused_task)
        expect(result).to eq(paused_task)
        expect(result.state).to eq("pending")
        expect(attack.reload.state).to eq("pending")
      end
    end


    context "when agent has no paused tasks" do
      before do
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns nil" do
        expect(service.send(:find_own_paused_task)).to be_nil
      end
    end

    context "when paused task has no uncracked hashes" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }

      before do
        create(:task, agent: agent, attack: attack, state: :paused, claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
        HashItem.where(hash_list_id: hash_list.id).update_all(cracked: true) # rubocop:disable Rails/SkipsModelValidations
      end

      it "returns nil" do
        expect(service.send(:find_own_paused_task)).to be_nil
      end
    end

    context "when resuming own paused task raises InvalidTransition" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }

      before do
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
        create(:hash_item, hash_list: hash_list, cracked: false)
        allow(Rails.logger).to receive(:error)
        allow_any_instance_of(Task).to receive(:resume!).and_raise( # rubocop:disable RSpec/AnyInstance
          StateMachines::InvalidTransition.new(Task.new, Task.state_machine(:state), :resume)
        )
      end

      it "returns nil and logs the error" do
        result = service.send(:find_own_paused_task)
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(/Failed to resume own paused task/)
      end
    end
  end

  describe "#find_own_paused_task takes priority in find_next_task" do
    let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
    let!(:paused_task) do
      create(:task, agent: agent, attack: attack, state: :paused, claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
    end

    before do
      create(:hash_item, hash_list: hash_list, cracked: false)
    end

    it "reclaims own paused task via find_next_task" do
      result = service.find_next_task
      expect(result).to eq(paused_task)
      expect(result.state).to eq("pending")
    end
  end

  describe "orphaned task grace period" do
    let(:other_agent) { create(:agent, user: user, projects: [project], state: :active) }
    let(:other_service) { described_class.new(other_agent) }
    let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }

    before do
      create(:hashcat_benchmark, agent: other_agent, hash_type: 0, hash_speed: 10_000_000)
      create(:hash_item, hash_list: hash_list, cracked: false)
    end

    context "when task was paused recently (within grace period)" do
      let!(:paused_task) do
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
      end

      it "does not allow another agent to claim the task" do
        expect(other_service.send(:find_unassigned_paused_task)).to be_nil
      end

      it "allows the original agent to reclaim via find_own_paused_task" do
        expect(service.send(:find_own_paused_task)).to eq(paused_task)
      end
    end

    context "when task has been paused beyond the grace period" do
      let!(:paused_task) do
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 31.minutes.ago)
      end

      it "allows another agent to claim the task" do
        result = other_service.send(:find_unassigned_paused_task)
        expect(result).to eq(paused_task)
        expect(result.state).to eq("pending")
      end

      it "reassigns agent_id to the claiming agent" do
        other_service.send(:find_unassigned_paused_task)
        expect(paused_task.reload.agent_id).to eq(other_agent.id)
      end
    end

    context "when owning agent is offline (immediate availability)" do
      let(:offline_agent) { create(:agent, user: user, projects: [project], state: :offline) }
      let!(:paused_task) do
        create(:task, agent: offline_agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 1.minute.ago)
      end

      before do
        create(:hashcat_benchmark, agent: offline_agent, hash_type: 0, hash_speed: 10_000_000)
      end

      it "allows another agent to claim the task immediately" do
        result = other_service.send(:find_unassigned_paused_task)
        expect(result).to eq(paused_task)
      end
    end

    context "when task has NULL paused_at (pre-migration)" do
      let!(:paused_task) do
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: nil)
      end

      it "treats NULL paused_at as available (no grace period)" do
        result = other_service.send(:find_unassigned_paused_task)
        expect(result).to eq(paused_task)
      end
    end

    context "when orphaned task's attack is also paused (shutdown cascade)" do
      before do
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 31.minutes.ago)
        attack.update!(state: :paused)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)
      end

      it "resumes the paused attack when another agent claims the orphaned task" do
        other_service.send(:find_unassigned_paused_task)
        expect(attack.reload.state).to eq("pending")
      end

      it "returns the task in pending state" do
        result = other_service.send(:find_unassigned_paused_task)
        expect(result.state).to eq("pending")
      end
    end

    context "when owning agent restarted (active) but grace period expired" do
      let!(:paused_task) do
        # agent is active (default let), task paused 31 min ago
        create(:task, agent: agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 31.minutes.ago)
      end

      it "allows another agent to claim despite owning agent being active" do
        result = other_service.send(:find_unassigned_paused_task)
        expect(result).to eq(paused_task)
      end
    end

    context "when resuming orphaned task raises StaleObjectError after ownership reassignment" do
      let(:offline_agent) { create(:agent, user: user, projects: [project], state: :offline) }

      before do
        create(:task, agent: offline_agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 31.minutes.ago)
        create(:hashcat_benchmark, agent: offline_agent, hash_type: 0, hash_speed: 10_000_000)
        create(:hash_item, hash_list: hash_list, cracked: false)
        allow(Rails.logger).to receive(:error)
        allow_any_instance_of(Task).to receive(:resume!).and_raise(ActiveRecord::StaleObjectError) # rubocop:disable RSpec/AnyInstance
      end

      it "preserves ownership reassignment and returns the task still paused" do
        result = other_service.send(:find_unassigned_paused_task)
        expect(result).not_to be_nil
        expect(result.agent_id).to eq(other_agent.id)
        expect(result.state).to eq("paused")
      end

      it "logs the error" do
        other_service.send(:find_unassigned_paused_task)
        expect(Rails.logger).to have_received(:error).with(/Failed to resume orphaned task/)
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

      it "allows the new agent to accept the reassigned task" do
        task = other_service.find_next_task
        expect(task.state).to eq("pending")

        # Verify the new agent can successfully accept the task
        expect { task.accept! }.to change { task.reload.state }.from("pending").to("running")
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
        allow(attack.campaign).to receive(:priority).and_raise(ActiveRecord::ActiveRecordError)
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

  describe "#create_new_task_if_eligible error handling" do
    let!(:attack) { create(:dictionary_attack, campaign: campaign, state: :pending) }

    before do
      create(:hash_item, hash_list: hash_list, cracked: false)
    end

    context "when task creation raises an error" do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error and returns nil" do
        allow(agent.tasks).to receive(:create).and_raise(ActiveRecord::StatementInvalid.new("DB connection lost"))

        result = service.send(:create_new_task_if_eligible, attack)
        expect(result).to be_nil
      end

      it "logs the error with attack id and error class" do
        allow(agent.tasks).to receive(:create).and_raise(ActiveRecord::StatementInvalid.new("DB connection lost"))

        service.send(:create_new_task_if_eligible, attack)
        expect(Rails.logger).to have_received(:error).with(/Error creating task for attack #{attack.id}.*StatementInvalid.*DB connection lost/)
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

  describe "skip-reason logging (#653)" do
    let(:log_messages) { [] }

    before do
      allow(Rails.logger).to receive(:info) { |*args, &block| log_messages << (block ? block.call : args.first) }
      allow(Rails.logger).to receive(:debug) { |*args, &block| log_messages << (block ? block.call : args.first) }
    end

    context "when no attacks match agent's hash types" do
      let(:unsupported_hash_type) { create(:hash_type, hashcat_mode: 9999, name: "Unsupported") }
      let(:unsupported_hash_list) { create(:hash_list, hash_type: unsupported_hash_type, project: project) }
      let(:unsupported_campaign) { create(:campaign, hash_list: unsupported_hash_list, project: project) }

      before do
        create(:dictionary_attack, campaign: unsupported_campaign, state: :pending)
        create(:hash_item, hash_list: unsupported_hash_list, cracked: false)
      end

      it "logs a summary with no_available_attacks reason" do
        service.find_next_task
        expect(log_messages).to include(match(/no_task_assigned.*no_available_attacks/))
      end

      it "includes agent_id in the summary" do
        service.find_next_task
        expect(log_messages).to include(match(/no_task_assigned.*agent_id=#{agent.id}/))
      end
    end

    context "when attacks exist but in a different project" do
      let(:other_project) { create(:project) }
      let(:other_hash_list) { create(:hash_list, hash_type: hash_type, project: other_project) }
      let(:other_campaign) { create(:campaign, hash_list: other_hash_list, project: other_project) }

      before do
        create(:dictionary_attack, campaign: other_campaign, state: :pending)
        create(:hash_item, hash_list: other_hash_list, cracked: false)
      end

      it "logs a summary with no_available_attacks reason" do
        service.find_next_task
        expect(log_messages).to include(match(/no_task_assigned.*no_available_attacks/))
      end
    end

    context "when agent does not meet performance threshold for any attack" do
      before do
        create(:dictionary_attack, campaign: campaign, state: :pending)
        create(:hash_item, hash_list: hash_list, cracked: false)
        agent.hashcat_benchmarks.find_each { |b| b.update!(hash_speed: 500) }
      end

      it "logs a summary with performance_threshold_not_met reason" do
        service.find_next_task
        expect(log_messages).to include(match(/no_task_assigned.*performance_threshold_not_met/))
      end
    end

    context "when all hashes are already cracked" do
      before do
        create(:dictionary_attack, campaign: campaign, state: :pending)
        hash_list.hash_items.delete_all
        create(:hash_item, hash_list: hash_list, cracked: true)
      end

      it "logs a summary with all_hashes_cracked reason" do
        service.find_next_task
        expect(log_messages).to include(match(/no_task_assigned.*all_hashes_cracked/))
      end
    end

    context "when a task is successfully assigned" do
      before do
        create(:dictionary_attack, campaign: campaign, state: :pending)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "does not log a no_task_assigned summary" do
        service.find_next_task
        expect(log_messages).not_to include(match(/no_task_assigned/))
      end
    end

    context "when pending tasks exist but belong to other agents" do
      let(:other_agent) { create(:agent, user: user, projects: [project]) }

      before do
        attack = create(:dictionary_attack, campaign: campaign, state: :pending)
        create(:hashcat_benchmark, agent: other_agent, hash_type: 0, hash_speed: 10_000_000)
        create(:task, agent: other_agent, attack: attack, state: :pending)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "logs a summary with pending_tasks_not_owned reason" do
        service.find_next_task
        expect(log_messages).to include(match(/no_task_assigned.*pending_tasks_not_owned/))
      end
    end

    context "when tasks are blocked by grace period" do
      let(:other_agent) { create(:agent, user: user, projects: [project], state: :active) }

      before do
        attack = create(:dictionary_attack, campaign: campaign, state: :running)
        create(:hashcat_benchmark, agent: other_agent, hash_type: 0, hash_speed: 10_000_000)
        create(:task, agent: other_agent, attack: attack, state: :paused,
                      claimed_by_agent_id: nil, paused_at: 5.minutes.ago)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "logs a summary with grace_period_active reason" do
        service.find_next_task
        expect(log_messages).to include(match(/no_task_assigned.*grace_period_active/))
      end
    end

    context "when multiple skip reasons apply" do
      let(:other_agent) { create(:agent, user: user, projects: [project]) }

      before do
        create(:hashcat_benchmark, agent: other_agent, hash_type: 0, hash_speed: 10_000_000)

        # Attack 1: all hashes cracked
        cracked_attack = create(:dictionary_attack, campaign: campaign, state: :pending)
        hash_list.hash_items.delete_all
        create(:hash_item, hash_list: hash_list, cracked: true)

        # Attack 2: pending task owned by another agent (needs a second campaign with uncracked hashes)
        hash_list2 = create(:hash_list, hash_type: hash_type, project: project)
        campaign2 = create(:campaign, hash_list: hash_list2, project: project)
        attack2 = create(:dictionary_attack, campaign: campaign2, state: :pending)
        create(:task, agent: other_agent, attack: attack2, state: :pending)
        create(:hash_item, hash_list: hash_list2, cracked: false)
      end

      it "logs comma-separated deduplicated reasons" do
        service.find_next_task
        summary = log_messages.find { |m| m.is_a?(String) && m.include?("no_task_assigned") }
        expect(summary).to include("all_hashes_cracked")
        expect(summary).to include("pending_tasks_not_owned")
      end
    end

    context "when logging summary raises internally" do
      let(:error_messages) { [] }

      before do
        allow(Rails.logger).to receive(:error) { |*args, &block| error_messages << (block ? block.call : args.first) }
        allow(Rails.logger).to receive(:info).and_raise(StandardError.new("logging failure"))
      end

      it "rescues and logs the error without crashing" do
        expect { service.send(:log_no_task_assigned_summary) }.not_to raise_error
        expect(error_messages).to include(match(/Failed to log task assignment summary/))
      end
    end
  end
end
