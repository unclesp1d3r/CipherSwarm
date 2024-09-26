# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The Task class represents a task in the CipherSwarm application.
# It is associated with an attack and an agent, and has many hashcat statuses and agent errors.
# The class includes state machine functionality to manage the state transitions of the task.
#
# Associations:
# - belongs_to :attack
# - belongs_to :agent
# - has_many :hashcat_statuses, dependent: :destroy
# - has_many :agent_errors, dependent: :destroy
#
# Validations:
# - Validates presence of :start_date
#
# Scopes:
# - default_scope: Orders tasks by :created_at
# - incomplete: Returns tasks with states :pending, :failed, or :running
# - inactive_for: Returns tasks inactive for a specified time
# - successful: Returns tasks with states :completed or :exhausted
#
# State Machine:
# - Initial state: :pending
# - States: :completed, :running, :paused, :failed, :exhausted, :pending
# - Events: :accept, :run, :complete, :pause, :resume, :error, :exhaust, :cancel, :accept_crack, :accept_status, :abandon
# - Callbacks: Various callbacks to handle state transitions and update related records
#
# Instance Methods:
# - estimated_finish_time: Returns the estimated finish time for the task
# - hash_list: Returns the hash list associated with the task's attack campaign
# - mark_attack_exhausted: Marks the attack as exhausted
# - progress_percentage: Calculates the progress percentage of the task
# - remove_old_status: Removes old status records from the hashcat_statuses table
# - uncracked_remaining: Returns true if there are uncracked hashes remaining in the hash list
# - update_activity_timestamp: Updates the activity timestamp of the task if the state has changed
#
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
class Task < ApplicationRecord
  belongs_to :attack, touch: true
  belongs_to :agent
  has_many :hashcat_statuses, dependent: :destroy # We're going to want to clean these up when the task is finished.
  has_many :agent_errors, dependent: :destroy
  validates :start_date, presence: true

  default_scope { order(:created_at) }
  scope :incomplete, -> { with_states(%i[pending failed running]) }
  scope :inactive_for, ->(time) { where(activity_timestamp: ...time.ago) }
  scope :successful, -> { with_states(:completed, :exhausted) }
  scope :finished, -> { with_states(:completed, :exhausted, :failed) }
  scope :running, -> { with_state(:running) }

  state_machine :state, initial: :pending do
    event :accept do
      transition pending: :running
      transition running: same
    end

    event :run do
      transition pending: :running
      transition any => same
    end

    event :complete do
      transition running: :completed
      transition pending: :completed if ->(task) { task.attack.hash_list.uncracked_count.zero? }
      transition any - [:running] => same
    end

    event :pause do
      transition %i[pending running] => :paused
      transition any => same
    end

    event :resume do
      transition paused: :pending
      transition any => same
    end

    event :error do
      transition running: :failed
    end

    event :exhaust do
      transition running: :exhausted
    end

    event :cancel do
      transition %i[pending running] => :failed
    end

    event :accept_crack do
      transition running: :completed, unless: :uncracked_remaining
      transition running: same
      transition all - %i[running completed] => :running
    end

    event :accept_status do
      transition paused: same
      transition all => :running
    end

    event :abandon do
      transition running: :pending
    end

    after_transition on: :running do |task|
      task.attack.accept
    end

    after_transition on: :completed do |task|
      task.attack.complete if attack.can_complete?
      task.hashcat_statuses.destroy_all
    end

    after_transition on: :exhausted do |task|
      task.attack.exhaust if attack.can_exhaust?
      task.hashcat_statuses.destroy_all
    end
    after_transition on: :abandon do |task|
      task.attack.abandon
    end

    after_transition on: :resume do |task|
      task.update(stale: true)
    end

    after_transition on: :exhausted, do: :mark_attack_exhausted

    after_transition any - [:pending] => any, do: :update_activity_timestamp

    state :completed
    state :running
    state :paused
    state :failed
    state :exhausted
    state :pending
  end

  # Calculates the estimated finish time for the task.
  #
  # This method retrieves the latest hashcat status with a running status and
  # determines the estimated finish time based on the attack type and status.
  #
  # @return [ActiveSupport::TimeWithZone, nil] The estimated finish time of the task, or nil if there are no running statuses.
  def estimated_finish_time
    # If the attack is a mask attack, we don't have a good way to estimate the stop time.
    return nil if attack.mask? && attack.mask_list.present?

    Rails.cache.fetch("#{cache_key_with_version}/estimated_finish_time", expires_in: 1.minute) do
      latest_status&.estimated_stop
    end
  end

  # Returns the hash list associated with the attack's campaign.
  #
  # @return [HashList, nil] The hash list associated with the attack's campaign, or nil if the attack is nil.
  def hash_list
    attack&.campaign&.hash_list
  end

  def latest_status
    hashcat_statuses.where(status: :running).order(time: :desc).first
  end

  # Marks the attack as exhausted if it is not already exhausted.
  # If the attack cannot be marked as exhausted, adds an error to the attack
  # and aborts the operation.
  #
  # @return [void]
  def mark_attack_exhausted
    return if attack.exhaust

    errors.add(:attack, "could not be marked exhausted")
    throw(:abort)
  end

  # Calculates the progress percentage of the current task.
  #
  # This method retrieves the latest status of the task where the status is `:running`,
  # and calculates the progress percentage based on the progress values and an increment multiplier.
  # The increment multiplier is determined by the guess base count and guess base offset.
  #
  # @return [Float] the progress percentage of the task, ranging from 0 to 100.
  #
  # @note The current implementation works well for dictionary attacks, but may need adjustments
  #       for other types of attacks.
  def progress_percentage
    latest_status&.progress_percentage || 0.0
  end

  def progress_text
    latest_status&.progress_text
  end

  # Removes old hashcat statuses if the number of statuses exceeds the configured limit.
  # The limit is retrieved from the application configuration.
  # Only statuses beyond the limit are destroyed, keeping the most recent ones.
  #
  # @return [void]
  def remove_old_status
    limit = ApplicationConfig.task_status_limit
    return unless limit.is_a?(Integer) && limit.positive?

    hashcat_statuses.order(created_at: :desc).offset(limit).destroy_all
  end

  # Checks if there are any uncracked hashes remaining.
  #
  # @return [Boolean] true if there are uncracked hashes, false otherwise.
  def uncracked_remaining
    hash_list.uncracked_count.positive?
  end

  # Updates the activity timestamp of the task to the current time in the application's time zone.
  # This method checks if the state of the task has changed and updates the activity timestamp accordingly.
  #
  # @return [Boolean] true if the timestamp was successfully updated, false otherwise.
  def update_activity_timestamp
    update(activity_timestamp: Time.zone.now) if state_changed?
  end
end
