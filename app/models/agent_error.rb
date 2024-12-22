# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents an error related to an agent in the system.
#
# An `AgentError` is associated with a specific agent and optionally a task.
# This class tracks details about the error, including its severity level,
# a descriptive message, and additional metadata.
#
# Associations:
# - `agent`: The agent responsible for the error.
# - `task`: The task related to the error (optional).
#
# Enumerations:
# - `severity`: The level of severity assigned to the error. Can be one of:
#   `info`, `warning`, `minor`, `major`, `critical`, or `fatal`.
#
# Validations:
# - Ensures that `message`, `severity`, and `metadata` are present.
#
# Scopes:
# - Defaults to ordering by creation timestamp in descending order.
#
# Behaviors:
# - Refreshes are broadcasted except in the test environment.
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

  enum :severity, { info: 0, warning: 1, minor: 2, major: 3, critical: 4, fatal: 5 }

  validates :message, presence: true
  validates :severity, presence: true
  validates :metadata, presence: true

  default_scope { order(created_at: :desc) }

  broadcasts_refreshes unless Rails.env.test?

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
