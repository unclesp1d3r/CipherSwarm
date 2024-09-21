# frozen_string_literal: true

#
# The Agent model represents an agent in the CipherSwarm application.
# It includes various associations, validations, scopes, and state machine
# transitions to manage the agent's lifecycle and behavior.
#
# Associations:
# - belongs_to :user
# - has_and_belongs_to_many :projects
# - has_many :tasks
# - has_many :hashcat_benchmarks
# - has_many :agent_errors
#
# Validations:
# - Validates the uniqueness and length of the token attribute.
# - Validates the presence and length of the name attribute.
#
# Scopes:
# - active: Returns agents that are active.
# - inactive_for: Returns agents that have been inactive for a specified time.
#
# State Machine:
# - Defines various states (pending, active, stopped, error, offline) and events
#   (activate, benchmarked, deactivate, shutdown, check_online, check_benchmark_age, heartbeat)
#   to manage the agent's state transitions.
#
# Methods:
# - advanced_configuration=: Sets the advanced configuration attribute.
# - aggregate_benchmarks: Aggregates the benchmarks for the agent.
# - allowed_hash_types: Returns an array of distinct hash types from the hashcat_benchmarks table.
# - benchmarks: Returns the last benchmarks recorded for the agent.
# - last_benchmark_date: Returns the date of the last benchmark.
# - last_benchmarks: Returns the last benchmarks recorded for the agent.
# - needs_benchmark?: Checks if the agent needs a benchmark.
# - new_task: Assigns a new task to the agent.
# - project_ids: Returns an array of project IDs associated with the agent.
# - set_update_interval: Sets the update interval for the agent.
#
# == Schema Information
#
# Table name: agents
#
#  id                                                            :bigint           not null, primary key
#  advanced_configuration(Advanced configuration for the agent.) :jsonb
#  client_signature(The signature of the agent)                  :text
#  devices(Devices that the agent supports)                      :string           default([]), is an Array
#  enabled(Is the agent active)                                  :boolean          default(TRUE), not null
#  last_ipaddress(Last known IP address)                         :string           default("")
#  last_seen_at(Last time the agent checked in)                  :datetime
#  name(Name of the agent)                                       :string           default(""), not null
#  operating_system(Operating system of the agent)               :integer          default("unknown")
#  state(The state of the agent)                                 :string           default("pending"), not null, indexed
#  token(Token used to authenticate the agent)                   :string(24)       indexed
#  created_at                                                    :datetime         not null
#  updated_at                                                    :datetime         not null
#  user_id(The user that the agent is associated with)           :bigint           not null, indexed
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

  scope :active, -> { where(state: :active) }
  scope :inactive_for, ->(time) { where(last_seen_at: ...time.ago) }
  default_scope { order(:created_at) }

  broadcasts_refreshes unless Rails.env.test?

  # The operating system of the agent.
  enum :operating_system, { unknown: 0, linux: 1, windows: 2, darwin: 3, other: 4 }

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
      agent.tasks.with_states(:running).each { |task| task.abandon }
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
      transition offline: :pending if ->(agent) { agent.needs_benchmark? }
      transition offline: :active
      transition any => same
    end

    state :pending
    state :active
    state :stopped
    state :error
    state :offline
  end

  # Sets the advanced configuration attribute.
  #
  # This method assigns a value to the advanced configuration attribute.
  # If the provided value is a string, it attempts to parse it as JSON.
  #
  # @param value [String, Hash] the value to set for advanced configuration
  def advanced_configuration=(value)
    self[:advanced_configuration] = value.is_a?(String) ? JSON.parse(value) : value
  end

  # Aggregates the benchmarks for the agent.
  #
  # This method groups the last benchmarks by hash type and sums the hash speeds.
  # It returns an array of strings representing the aggregated benchmarks.
  #
  # @return [Array<String>, nil] An array of aggregated benchmark strings, or nil if no benchmarks are available.
  def aggregate_benchmarks
    return nil if last_benchmarks.blank?
    benchmark_summaries = last_benchmarks&.group(:hash_type)&.sum(:hash_speed)
    return nil if benchmark_summaries.blank?
    benchmark_summaries.map { |hash_type, speed| format_benchmark_summary(hash_type, speed) }
  end

  # Returns an array of distinct hash types from the hashcat_benchmarks table.
  #
  # @return [Array<String>] An array of distinct hash types.
  def allowed_hash_types
    hashcat_benchmarks.distinct.pluck(:hash_type)
  end

  # Returns the last benchmarks recorded for the agent as an array of strings.
  #
  # If there are no benchmarks available, it returns nil.
  #
  # @return [Array<String>, nil] The last benchmarks recorded for the agent, or nil if there are no benchmarks.
  def benchmarks
    if last_benchmarks.blank?
      return nil
    end
    last_benchmarks.map(&:to_s)
  end

  # Formats a benchmark summary string based on the hash type and speed.
  #
  # @param hash_type [Integer] The hashcat mode identifier for the hash type.
  # @param speed [Float] The speed of the hashing process in hashes per second.
  # @return [String] A formatted string summarizing the benchmark. If the hash type
  #   is found in the HashType model, it includes the hash type name and a human-readable
  #   speed. Otherwise, it returns a string with the hash type and speed in h/s.
  def format_benchmark_summary(hash_type, speed)
    hash_type_record = Rails.cache.fetch("#{cache_key_with_version}/hash_type/#{hash_type}/name", expires_in: 1.week) do
      HashType.find_by(hashcat_mode: hash_type)
    end
    if hash_type_record.nil?
      "#{hash_type} #{speed} h/s"
    else
      "#{hash_type} (#{hash_type_record.name}) - #{number_to_human(speed, prefix: :si)} hashes/sec"
    end
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

  # Determines if the agent needs a benchmark based on the last benchmark date
  # and the maximum allowed benchmark age defined in the application configuration.
  #
  # @return [Boolean] true if the agent needs a benchmark, false otherwise
  def needs_benchmark?
    # A benchmark is needed if the last_benchmark_date is older than the max_benchmark_age.
    last_benchmark_date <= ApplicationConfig.max_benchmark_age.ago
  end

  # Returns the next task for the agent to work on, based on various criteria.
  #
  # First, the method checks for any incomplete tasks already assigned to the agent.
  # - If an incomplete task exists and has no associated fatal errors, it is returned.
  #
  # If there are no existing tasks assigned to the agent, the method proceeds to find
  # pending tasks across the projects the agent is associated with.
  # - It retrieves tasks from hash types the agent supports.
  #
  # For each pending task found, the method:
  # - Checks if the task has any uncracked hashes.
  # - Returns tasks in a 'failed' state first, if there are no fatal errors for these tasks.
  # - Returns a task in a 'pending' state if found.
  #
  # If there are no incomplete tasks for an attack, creates a new task.
  #
  # If no pending tasks are found or created, returns `nil`.
  #
  # @return [Task, nil] The next task for the agent, or nil if no task is found.
  def new_task
    # Immediately return the first incomplete task if there's no fatal errors for it.
    incomplete_task = tasks.incomplete.find do |task|
      !agent_errors.exists?(severity: :fatal, task_id: task.id) && task.uncracked_remaining
    end

    return incomplete_task if incomplete_task

    # Ensure projects are present.
    return nil if project_ids.blank?

    # Get hash types allowed for the agent. This does not change often, so we cache it for an hour.
    allowed_hash_type_ids = Rails.cache.fetch("#{cache_key_with_version}/allowed_hash_types", expires_in: 1.hour) do
      HashType.where(hashcat_mode: allowed_hash_types).pluck(:id)
    end

    # Fetch applicable attacks.
    attacks = Attack.incomplete.joins(campaign: { hash_list: :hash_type })
                    .where(campaigns: { project_id: project_ids })
                    .where(hash_lists: { hash_type_id: allowed_hash_type_ids })
                    .order(:complexity_value, :created_at)
    return nil if attacks.blank?

    attacks.each do |attack|
      next if attack.uncracked_count.zero?

      # Return the first failed task without fatal errors.
      failed_task = attack.tasks.with_state(:failed).find do |task|
        !agent_errors.exists?(severity: :fatal, task_id: task.id)
      end
      return failed_task if failed_task

      # Return the first pending task.
      pending_task = attack.tasks.with_state(:pending).first
      return pending_task if pending_task

      # If no pending tasks, create a new task for the agent.
      if attack.tasks.with_state(:pending).none?
        return tasks.create(attack: attack, start_date: Time.zone.now)
      end
    end

    # If no tasks can be assigned, return nil.
    nil
  end

  # Returns an array of project IDs associated with the agent.
  #
  # @return [Array<Integer>] an array of project IDs
  def project_ids
    Rails.cache.fetch("#{cache_key_with_version}/project_ids", expires_in: 1.hour) do
      projects.pluck(:id)
    end
  end

  # Sets the update interval for the agent.
  #
  # The interval is a random number between 5 and 60 (inclusive).
  # This interval is then assigned to the "agent_update_interval" key
  # in the advanced_configuration hash.
  #
  # @return [void]
  def set_update_interval
    interval = rand(5..60)
    advanced_configuration["agent_update_interval"] = interval
  end
end
