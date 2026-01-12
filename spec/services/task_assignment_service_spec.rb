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
end
