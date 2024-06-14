# frozen_string_literal: true

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
#  agent_id(The agent that the task is assigned to, if any.)          :bigint           not null, indexed
#  attack_id(The attack that the task is associated with.)            :bigint           not null, indexed
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
#  fk_rails_...  (attack_id => attacks.id)
#
class Task < ApplicationRecord
  belongs_to :attack, touch: true
  belongs_to :agent, touch: true
  has_many :hashcat_statuses, dependent: :destroy # We're going to want to clean these up when the task is finished.
  has_many :agent_errors, dependent: :destroy
  validates :start_date, presence: true

  default_scope { order(:created_at) }
  scope :incomplete, -> { with_states(%i[pending failed running]) }
  scope :inactive_for, ->(time) { where(activity_timestamp: ...time.ago) }
  scope :successful, -> { with_states(:completed, :exhausted) }

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
      transition running: :paused
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
    end

    after_transition on: :exhausted do |task|
      task.attack.exhaust if attack.can_exhaust?
    end
    after_transition on: :abandon do |task|
      task.attack.abandon if task.attack.can_abandon?
    end

    after_transition on: :exhausted, do: :mark_attack_exhausted
    after_transition on: :exhausted, do: :remove_old_status

    after_transition any - [:pending] => any, do: :update_activity_timestamp

    state :completed
    state :running
    state :paused
    state :failed
    state :exhausted
    state :pending
  end

  # Returns the estimated finish time for the task.
  #
  # This method retrieves the latest running status of the task from the `hashcat_statuses` association,
  # and returns the estimated stop time of that status. If there are no running statuses, it returns nil.
  #
  # @return [Time, nil] The estimated finish time of the task, or nil if there are no running statuses.
  def estimated_finish_time
    latest_status = hashcat_statuses.where(status: :running).order(time: :desc).first
    return nil if latest_status.nil?

    latest_status.estimated_stop
  end

  # Returns the hash list associated with the task's attack campaign.
  def hash_list
    attack.campaign.hash_list
  end

  # Marks the attack as exhausted.
  #
  # If the attack is already exhausted, the method returns early.
  # Otherwise, it adds an error message to the `errors` collection and throws an `:abort` symbol.
  def mark_attack_exhausted
    return if attack.exhaust

    errors.add(:attack, "could not be marked exhausted")
    throw(:abort)
  end

  # Calculates the progress percentage of the task.
  #
  # Returns:
  # - The progress percentage as a float value between 0 and 1.
  #
  def progress_percentage
    latest_status = hashcat_statuses.where(status: :running).order(time: :desc).first
    return 0 if latest_status.nil?

    (latest_status.progress[0].to_f / latest_status.progress[1].to_f) * 100
  end

  # Removes old status records from the hashcat_statuses table.
  #
  # This method deletes status records from the hashcat_statuses table, starting from the 11th record (offset 10) in descending order of time.
  #
  # Example:
  #   task.remove_old_status
  #
  # This will remove the old status records from the hashcat_statuses table.
  def remove_old_status
    old_statuses = hashcat_statuses.order(time: :desc).offset(10)
    old_statuses.destroy_all
  end

  # Returns true if there are uncracked hashes remaining in the hash list, false otherwise.
  def uncracked_remaining
    hash_list.uncracked_count.positive?
  end

  # Updates the activity timestamp of the task if the state has changed.
  #
  # This method is responsible for updating the activity timestamp of the task
  # to the current time in the application's time zone. It checks if the state
  # of the task has changed and updates the activity timestamp accordingly.
  #
  # Example usage:
  #   task.update_activity_timestamp
  #
  # Returns nothing.
  def update_activity_timestamp
    update(activity_timestamp: Time.zone.now) if state_changed?
  end
end
