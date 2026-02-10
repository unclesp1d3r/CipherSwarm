# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Records and manages error events from agents during task execution.
#
# @relationships
# - belongs_to :agent, :task (touch: true, task optional)
#
# @enums
# - severity: info, warning, minor, major, critical, fatal
#
# @validations
# - message, severity, metadata: present
#
# @scopes
# - default: ordered by created_at desc
#
# @methods
# - attack_id: retrieves associated attack ID from task
# - to_s: formats error as "timestamp severity: message"
#
# == Schema Information
#
# Table name: agent_errors
#
#  id                                              :bigint           not null, primary key
#  message(The error message)                      :string           not null
#  metadata(Additional metadata about the error)   :jsonb            not null
#  severity(The severity of the error)             :integer          default("info"), not null
#  created_at                                      :datetime         not null, indexed
#  updated_at                                      :datetime         not null
#  agent_id(The agent that caused the error)       :bigint           not null, indexed
#  task_id(The task that caused the error, if any) :bigint           indexed
#
# Indexes
#
#  index_agent_errors_on_agent_id    (agent_id)
#  index_agent_errors_on_created_at  (created_at)
#  index_agent_errors_on_task_id     (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id) ON DELETE => cascade
#  fk_rails_...  (task_id => tasks.id) ON DELETE => nullify
#
class AgentError < ApplicationRecord
  belongs_to :agent, touch: true
  belongs_to :task, optional: true, touch: true

  enum :severity, { info: 0, warning: 1, minor: 2, major: 3, critical: 4, fatal: 5 }

  validates :message, presence: true
  validates :severity, presence: true
  validates :metadata, presence: true

  default_scope { order(created_at: :desc) }

  include SafeBroadcasting

  broadcasts_refreshes

  # Scopes for common query patterns
  scope :for_campaign, lambda { |campaign_id|
    joins(task: :attack).where(attacks: { campaign_id: campaign_id })
  }

  scope :older_than, ->(date) { where(created_at: ...date) }

  # Removes agent error records older than the configured retention period.
  # Uses the `older_than` scope with `ApplicationConfig.agent_error_retention`.
  #
  # @return [Integer] the number of deleted records
  def self.remove_old_errors
    older_than(ApplicationConfig.agent_error_retention.ago).delete_all
  end

  # Returns the latest error for each attack in the given list.
  #
  # Uses PostgreSQL DISTINCT ON for efficient single-query retrieval.
  # Returns a hash mapping attack_id => AgentError.
  #
  # @param attack_ids [Array<Integer>] list of attack IDs to find errors for
  # @return [Hash<Integer, AgentError>] map of attack_id to latest error
  def self.latest_per_attack(attack_ids)
    return {} if attack_ids.blank?

    find_by_sql([<<-SQL.squish, attack_ids])
      SELECT DISTINCT ON (tasks.attack_id)
             agent_errors.*,
             tasks.attack_id AS associated_attack_id
      FROM agent_errors
      INNER JOIN tasks ON tasks.id = agent_errors.task_id
      WHERE tasks.attack_id IN (?)
      ORDER BY tasks.attack_id, agent_errors.created_at DESC
    SQL
      .index_by(&:associated_attack_id)
  end

  # Retrieves the attack ID associated with the task.
  #
  # This method first checks if the `task_id` is present. If not, it returns `nil`.
  # Then, it attempts to find the task using the `task_id`. If the task is not found, it returns `nil`.
  # If the task is found, it returns the `attack_id` of the task.
  #
  # @return [Integer, nil] the attack ID of the task, or `nil` if the `task_id` is blank or the task is not found.
  def attack_id
    return if task_id.blank?

    task = Task.find(task_id)
    return if task.blank?
    task.attack_id
  end

  # Returns a string representation of the agent error.
  # The format includes the creation timestamp in short format,
  # the severity level, and the error message.
  #
  # @return [String] the formatted string representation of the agent error
  def to_s
    "#{created_at.to_fs(:short)} #{severity}: #{message}"
  end
end
