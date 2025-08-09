# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: tasks
#
#  id                                                                                                     :bigint           not null, primary key
#  activity_timestamp(The timestamp of the last activity on the task)                                     :datetime
#  keyspace_limit(The maximum number of keyspace values to process.)                                      :integer          default(0)
#  keyspace_offset(The starting keyspace offset.)                                                         :integer          default(0)
#  stale(If new cracks since the last check, the task is stale and the new cracks need to be downloaded.) :boolean          default(FALSE), not null
#  start_date(The date and time that the task was started.)                                               :datetime         not null
#  state                                                                                                  :string           default("pending"), not null, indexed
#  created_at                                                                                             :datetime         not null
#  updated_at                                                                                             :datetime         not null
#  agent_id(The agent that the task is assigned to, if any.)                                              :bigint           not null, indexed
#  attack_id(The attack that the task is associated with.)                                                :bigint           not null, indexed
#
# Indexes
#
#  index_tasks_on_agent_id   (agent_id)
#  index_tasks_on_attack_id  (attack_id)
#  index_tasks_on_state      (state)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (attack_id => attacks.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :task do
    attack factory: :dictionary_attack
    agent
    start_date { Faker::Time.between(from: DateTime.now - 1, to: DateTime.now) }
  end
end
