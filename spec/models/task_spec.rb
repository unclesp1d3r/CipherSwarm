# == Schema Information
#
# Table name: tasks
#
#  id                                                                 :bigint           not null, primary key
#  activity_timestamp(The timestamp of the last activity on the task) :datetime
#  keyspace_limit(The maximum number of keyspace values to process.)  :integer          default(0)
#  keyspace_offset(The starting keyspace offset.)                     :integer          default(0)
#  start_date(The date and time that the task was started.)           :datetime         not null
#  state                                                              :string           default("pending"), not null, indexed
#  created_at                                                         :datetime         not null
#  updated_at                                                         :datetime         not null
#  agent_id(The agent that the task is assigned to, if any.)          :bigint           indexed
#  operation_id(The attack that the task is associated with.)         :bigint           not null, indexed
#
# Indexes
#
#  index_tasks_on_agent_id      (agent_id)
#  index_tasks_on_operation_id  (operation_id)
#  index_tasks_on_state         (state)
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
  end

  describe 'scopes' do
    describe '.incomplete' do
      let!(:attack) { create(:attack, name: 'scope_test_attack') }
      let!(:task_completed) { create(:task, state: 'completed', attack: attack) }
      let!(:task_pending) { create(:task, state: 'pending', attack: attack) }
      let!(:task_running) { create(:task, state: 'running', attack: attack) }
      let!(:task_exhausted) { create(:task, state: 'exhausted', attack: attack) }

      it 'returns tasks that are not completed' do
        expect(described_class.incomplete).to include(task_pending)
      end

      it "doesn't return incomplete tasks" do
        expect(described_class.incomplete).not_to include([ task_completed, task_running, task_exhausted ])
      end
    end
  end
end
