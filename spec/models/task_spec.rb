# == Schema Information
#
# Table name: tasks
#
#  id                                                                 :bigint           not null, primary key
#  activity_timestamp(The timestamp of the last activity on the task) :datetime
#  start_date(The date and time that the task was started.)           :datetime         not null
#  status(Task status)                                                :integer          default("pending"), not null, indexed
#  created_at                                                         :datetime         not null
#  updated_at                                                         :datetime         not null
#  agent_id(The agent that the task is assigned to, if any.)          :bigint           indexed
#  operation_id(The attack that the task is associated with.)         :bigint           not null, indexed
#
# Indexes
#
#  index_tasks_on_agent_id      (agent_id)
#  index_tasks_on_operation_id  (operation_id)
#  index_tasks_on_status        (status)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (operation_id => operations.id)
#
require 'rails_helper'

RSpec.describe Task do
  subject { build(:task) }

  describe 'associations' do
    it { is_expected.to belong_to(:attack) }
    it { is_expected.to belong_to(:agent) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to define_enum_for(:status).with_values({ pending: 0, running: 1, completed: 2, paused: 3, failed: 4, exhausted: 5 }) }
  end

  describe 'scopes' do
    describe '.incomplete' do
      let!(:attack) { create(:attack, name: 'scope_test_attack') }
      let!(:task_completed) { create(:task, status: :completed, attack: attack) }
      let!(:task_pending) { create(:task, status: :pending, attack: attack) }
      let!(:task_running) { create(:task, status: :running, attack: attack) }

      it 'returns tasks that are not completed' do
        expect(described_class.incomplete).to include(task_pending, task_running)
      end

      it "doesn't return completed tasks" do
        expect(described_class.incomplete).not_to include(task_completed)
      end
    end
  end

  describe 'methods' do
    it { is_expected.to respond_to(:update_status) }
  end
end
