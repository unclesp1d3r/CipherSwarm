# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_errors
#
#  id                                              :bigint           not null, primary key
#  message(The error message)                      :string           not null
#  metadata(Additional metadata about the error)   :jsonb            not null
#  severity(The severity of the error)             :integer          default("info"), not null
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  agent_id(The agent that caused the error)       :bigint           not null, indexed
#  task_id(The task that caused the error, if any) :bigint           indexed
#
# Indexes
#
#  index_agent_errors_on_agent_id  (agent_id)
#  index_agent_errors_on_task_id   (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (task_id => tasks.id)
#
FactoryBot.define do
  factory :agent_error do
    message { Faker::Lorem.sentence }
    metadata { { key: Faker::Lorem.word } }
    severity { :warning }
    agent
  end
end
