# frozen_string_literal: true

# == Schema Information
#
# Table name: agents
#
#  id                                                                         :bigint           not null, primary key
#  active(Is the agent active)                                                :boolean          default(TRUE), not null
#  advanced_configuration(Advanced configuration for the agent.)              :jsonb
#  client_signature(The signature of the agent)                               :text
#  command_parameters(Parameters to be passed to the agent when it checks in) :text
#  cpu_only(Only use for CPU only tasks)                                      :boolean          default(FALSE), not null
#  devices(Devices that the agent supports)                                   :string           default([]), is an Array
#  ignore_errors(Ignore errors, continue to next task)                        :boolean          default(FALSE), not null
#  last_ipaddress(Last known IP address)                                      :string           default("")
#  last_seen_at(Last time the agent checked in)                               :datetime
#  name(Name of the agent)                                                    :string           default(""), not null
#  operating_system(Operating system of the agent)                            :integer          default("unknown")
#  state(The state of the agent)                                              :string           default("pending"), not null, indexed
#  token(Token used to authenticate the agent)                                :string(24)       indexed
#  trusted(Is the agent trusted to handle sensitive data)                     :boolean          default(FALSE), not null
#  created_at                                                                 :datetime         not null
#  updated_at                                                                 :datetime         not null
#  user_id(The user that the agent is associated with)                        :bigint           not null, indexed
#
# Indexes
#
#  index_agents_on_state    (state)
#  index_agents_on_token    (token) UNIQUE
#  index_agents_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Agent < ApplicationRecord
  include StoreModel::NestedAttributes

  belongs_to :user, touch: true
  has_and_belongs_to_many :projects, touch: true
  has_many :tasks, dependent: :destroy
  has_many :hashcat_benchmarks, dependent: :destroy
  has_many :agent_errors, dependent: :destroy
  validates :token, uniqueness: true, length: { is: 24 }
  has_secure_token :token # Generates a unique token for the agent.
  attr_readonly :token # The token should not be updated after creation.
  before_create :set_update_interval

  attribute :advanced_configuration, AdvancedConfiguration.to_type
  accepts_nested_attributes_for :advanced_configuration, allow_destroy: true

  validates :name, presence: true, length: { maximum: 255 }

  scope :active, -> { where(active: true) }
  scope :inactive_for, ->(time) { where(last_seen_at: ...time.ago) }

  broadcasts_refreshes unless Rails.env.test?

  # The operating system of the agent.
  enum operating_system: { unknown: 0, linux: 1, windows: 2, darwin: 3, other: 4 }

  state_machine :state, initial: :pending do
    event :activate do
      transition active: same
      transition pending: :active
    end

    event :benchmarked do
      transition pending: :active
      transition any => same
    end

    event :deactivate do
      transition active: :stopped
    end

    event :shutdown do
      transition any => :offline
    end

    after_transition on: :shutdown do |agent|
      agent.tasks.with_states(:running).each do |task|
        task.abandon if task.can_abandon?
      end
    end

    event :check_online do
      # If the agent has checked in within the last 30 minutes, mark it as online.
      transition any => :offline if ->(agent) { agent.last_seen_at >= ApplicationConfig.agent_considered_offline_time.ago }
      transition any => same
    end

    event :check_benchmark_age do
      transition active: :pending if ->(agent) { agent.needs_benchmark? }
      transition any => same
    end

    event :heartbeat do
      # If the agent has been offline for more than 12 hours, we'll transition it to pending.
      # This will require the agent to benchmark again.
      transition offline: :pending if ->(agent) { agent.last_seen_at < ApplicationConfig.max_offline_time.ago }
      transition offline: :active
      transition any => same
    end

    state :pending
    state :active
    state :stopped
    state :error
    state :offline
  end

  def advanced_configuration=(value)
    self[:advanced_configuration] = value.is_a?(String) ? JSON.parse(value) : value
  end

  # Returns an array of distinct hash types from the hashcat_benchmarks table.
  #
  # @return [Array<String>] An array of distinct hash types.
  def allowed_hash_types
    hashcat_benchmarks.distinct.pluck(:hash_type)
  end

  def benchmarks
    if last_benchmarks.blank?
      return nil
    end
    last_benchmarks.map(&:to_s)
  end

  # Returns the date of the last benchmark.
  #
  # If there are no benchmarks, it returns the date from a year ago.
  #
  # @return [Date, ActiveSupport::TimeWithZone] The date of the last benchmark.
  def last_benchmark_date
    if hashcat_benchmarks.empty?
      # If there are no benchmarks, we'll just return the date from a year ago.
      created_at - 365.days
    else
      hashcat_benchmarks.order(benchmark_date: :desc).first.benchmark_date
    end
  end

  # Returns the last benchmarks recorded for the agent.
  #
  # If there are no benchmarks available, it returns nil.
  #
  # @return [ActiveRecord::Relation, nil] The last benchmarks recorded for the agent, or nil if there are no benchmarks.
  def last_benchmarks
    return nil if hashcat_benchmarks.empty?
    max = hashcat_benchmarks.maximum(:benchmark_date)
    hashcat_benchmarks.where(benchmark_date: (max.all_day)).order(hash_type: :asc)
  end

  def needs_benchmark?
    last_benchmark_date <= ApplicationConfig.max_benchmark_age.ago
  end

  # Public: Finds or creates a new task for the agent.
  #
  # This method is responsible for assigning a new task to the agent. It follows a specific logic to determine which task to assign.
  # If there are any incomplete tasks already assigned to the agent, it returns the first incomplete task.
  # If there are no incomplete tasks assigned to the agent, it looks for pending tasks in the projects the agent is assigned to.
  # It filters the campaigns based on the hash types supported by the agent and returns the first pending task from the campaigns.
  # If no pending tasks are found, it creates a new task for the agent from the first available campaign.
  #
  # Returns the assigned task or nil if no task is found.
  def new_task
    # We'll start with no prioritization, just get the first pending task.
    # We can add prioritization later.

    # first we assign any tasks that are assigned to the agent and are incomplete.
    if tasks.incomplete.any? && tasks.incomplete.where(agent_id: id).any?
      incomplete_task = tasks.incomplete.where(agent_id: id).first

      # If the task is incomplete and there are no errors for the task, we'll return the task.
      return incomplete_task if incomplete_task.present? &&
        !agent_errors.where(severity: :fatal).where(task_id: incomplete_task.id).any? &&
        incomplete_task.uncracked_remaining
    end

    # Ok, so there's no existing tasks already assigned to the agent.
    # Let's see if we can find any pending tasks in the projects the agent is assigned to.
    return nil if project_ids.blank? # should never happen, but just in case.

    # Let's filter the campaigns to only include the hash types the agent supports.
    campaigns = Campaign.in_projects(project_ids).all
    hash_type_ids = HashType.where(hashcat_mode: allowed_hash_types).pluck(:id)
    campaigns = campaigns.includes(hash_list: [:hash_type]).where(hash_list: { hash_type_id: hash_type_ids })
    campaigns = campaigns.order(:created_at)

    return nil if campaigns.blank? # No campaigns found.

    campaigns.each do |campaign|
      next if campaign.uncracked_count.zero?
      campaign.attacks.incomplete.each do |attack|
        # We'll return any failed tasks first.
        if attack.tasks.without_state(%i[completed exhausted running]).any?
          failed_task = attack.tasks.with_state(:failed).first
          if failed_task.present? && agent_errors.where(severity: :fatal).where(task_id: failed_task.id).any?
            next
          end
          return failed_task if failed_task.present?

          # Next we'll return any tasks that are pending.
          # We might want to add some prioritization here.
          # We'll only return the first one we find.
          pending_task = attack.tasks.with_state(:pending).first
          return pending_task if pending_task.present?
        end
        # Ok, no work to steal, so let's create a new task.
        # We'll create a new task for the agent.
        return tasks.create(attack: attack, start_date: Time.zone.now)
      end
    end

    # If no pending tasks are found, we'll return nil.
    nil
  end

  def project_ids
    projects.pluck(:id)
  end

  # Sets the update interval for the agent.
  #
  # This method generates a random interval between 5 and 15 and assigns it to the
  # "agent_update_interval" key in the advanced configuration.
  #
  # Example:
  #   agent.set_update_interval
  #
  # Returns:
  #   The updated advanced configuration with the new update interval.
  def set_update_interval
    interval = rand(5..15)
    advanced_configuration["agent_update_interval"] = interval
  end
end
