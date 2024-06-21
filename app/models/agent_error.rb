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
class AgentError < ApplicationRecord
  belongs_to :agent, touch: true
  belongs_to :task, optional: true, touch: true

  enum severity: { info: 0, warning: 1, minor: 2, major: 3, critical: 4, fatal: 5 }

  validates :message, presence: true
  validates :severity, presence: true
  validates :metadata, presence: true

  broadcasts_refreshes unless Rails.env.test?

  def attack_id
    return if task_id.blank?

    task = Task.find(task_id)
    return if task.blank?
    task.attack_id
  end

  def to_s
    "#{created_at.to_fs(:short)} #{severity}: #{message}"
  end
end
