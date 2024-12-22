# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents a task in the system, which is associated with an attack and an agent.
# Tasks have several states and can transition between states based on various events.
# They track progress and status updates, and include functionality for managing hashcat statuses.
# Associations
# * Belongs to an attack.
# * Belongs to an agent.
# * Has many hashcat statuses, which are destroyed when the task is finished.
# * Has many agent errors, which are also destroyed when no longer needed.
# Validations
# * Requires the presence of a start date.
# Scopes
# * `incomplete`: Returns tasks that are pending, failed, or running.
# * `inactive_for(time)`: Filters tasks that have not seen activity for a given duration.
# * `successful`: Retrieves tasks that are completed or exhausted.
# * `finished`: Fetches tasks that are completed, exhausted, or failed.
# * `running`: Retrieves tasks currently in the running state.
# State Machine
# Initial state: `pending`
# Events:
# * `accept`: Transitions pending tasks to running or keeps running tasks in the same state.
# * `run`: Transitions pending tasks to running or leaves any state unchanged.
# * `complete`: Marks running tasks as completed or transitions pending tasks to completed
#   if there are no uncracked hashes remaining.
# * `pause`: Moves tasks from pending or running states to paused.
# * `resume`: Resumes a paused task, transitioning it to pending.
# * `error`: Marks running tasks as failed.
# * `exhaust`: Marks running tasks as exhausted.
# * `cancel`: Cancels tasks that are in the pending or running state, transitioning them to failed.
# * `accept_crack`: Completes or updates running tasks depending on the presence of uncracked hashes.
# * `accept_status`: Updates tasks to running unless already paused.
# * `abandon`: Moves running tasks back to pending.
# Callbacks
# * Updates attack and task states or timestamps based on transitions.
# * Example callbacks:
#   * After `running`: Invokes the `accept` action on the associated attack.
#   * After `completed`: Completes the attack if possible and clears hashcat statuses.
#   * After `exhausted`: Marks the attack as exhausted and removes hashcat statuses.
#   * After `resume`: Marks the task as stale.
#   * After general state transitions (excluding `pending`): Updates activity timestamps.
# Available states:
# * `pending`
# * `completed`
# * `running`
# * `paused`
# * `failed`
# * `exhausted`
# Methods
#
# * `estimated_finish_time` - Calculates the estimated time by which the task is expected to finish.
#   Returns `nil` for mask attacks with a defined mask list or if no running statuses are available.
#
# * `hash_list` - Retrieves the hash list associated with the attack's campaign.
#
# * `latest_status` - Returns the latest hashcat status with the `:running` status.
#
# * `mark_attack_exhausted` - Attempts to mark the attack as exhausted and adds an error if it fails.
#
# * `progress_percentage` - Computes the task's progress percentage (0-100) based on the latest status.
#
# * `progress_text` - Returns a progress description from the latest status, if available.
#
# * `remove_old_status` - Deletes hashcat statuses exceeding a configured limit, keeping the most recent entries.
#
# * `uncracked_remaining` - Determines whether there are any remaining uncracked hashes.
#
# * `update_activity_timestamp` - Updates the task's activity timestamp when the state changes.
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
