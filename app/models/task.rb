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
  validates :start_date, presence: true

  scope :incomplete, -> { with_states([ :pending, :failed, :running ]) }

  state_machine :state, initial: :pending do
    event :accept do
      transition pending: :running
      transition running: same
    end

    event :run do
      transition pending: :running
    end

    event :complete do
      transition running: :completed
      transition pending: :completed if ->(task) { task.attack.hash_list.uncracked_count.zero? }
      transition any - [ :running ] => same
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
      transition [ :pending, :running ] => :failed
    end

    event :accept_crack do
      transition running: :completed, unless: :uncracked_remaining
      transition running: same
      transition all - [ :running, :completed ] => :running
    end

    event :accept_status do
      transition all => :running
    end

    event :abandon do
      # If the task has been inactive for more than 30 minutes, it should be marked as failed.
      transition running: :failed if ->(task) { task.activity_timestamp > 30.minutes.ago }
      transition all: same
    end

    after_transition on: :running do |task|
      task.attack.accept!
    end

    after_transition on: :completed do |task|
      task.attack.complete if attack.can_complete?
    end

    after_transition on: :exhausted do |task|
      task.attack.exhaust if attack.can_exhaust?
    end

    after_transition on: :exhausted, do: :mark_attack_exhausted
    after_transition on: :exhausted, do: :remove_old_status

    after_transition any - [ :pending ] => any, do: :update_activity_timestamp

    state :completed
    state :running
    state :paused
    state :failed
    state :exhausted
    state :pending
  end

  def uncracked_remaining
    hash_list.uncracked_count > 0
  end

  def hash_list
    attack.campaign.hash_list
  end

  # The activity_timestamp attribute is used to track the last check-in time of the agent on the task.
  # If it has been more than 30 minutes since the last check-in, the task is considered to be inactive and should go back to the pending state.
  def update_activity_timestamp
    update(activity_timestamp: Time.zone.now) if state_changed?
  end

  def estimated_finish_time
    latest_status = hashcat_statuses.order(time: :desc).first
    return nil if latest_status.nil?
    latest_status.estimated_stop
  end

  def progress_percentage
    latest_status = hashcat_statuses.order(time: :desc).first
    return 0 if latest_status.nil?
    latest_status.progress[1].to_f / latest_status.progress[0].to_f
  end

  def remove_old_status
    hashcat_statuses.order(created_at: :desc).offset(10).destroy_all
  end

  def mark_attack_exhausted
    unless attack.exhaust
      errors.add(:attack, "could not be marked exhausted")
      throw(:abort)
    end
  end
end
