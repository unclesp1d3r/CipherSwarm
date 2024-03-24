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

RSpec.describe Task, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
