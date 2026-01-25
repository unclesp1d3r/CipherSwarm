# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents a worker node that executes hash cracking tasks.
#
# @includes
# - StoreModel::NestedAttributes: enables nested configuration
#
# @relationships
# - belongs_to :user (touch: true)
# - has_and_belongs_to_many :projects (touch: true)
# - has_many :tasks, :hashcat_benchmarks, :agent_errors (dependent: destroy)
#
# @validations
# - token: unique, 24 chars
# - host_name: present, max 255 chars
# - custom_label: unique if present, max 255 chars
#
# @attributes
# - advanced_configuration: nested AdvancedConfiguration
#
# @enums
# - operating_system: unknown, linux, windows, darwin, other
#
# @scopes
# - active: currently active agents
# - inactive_for(time): not seen since specified time
# - default: ordered by created_at
#
# @callbacks
# - before_create: sets update interval
#
# == Schema Information
#
# Table name: agents
#
#  id                                                                                     :bigint           not null, primary key
#  advanced_configuration(Advanced configuration for the agent.)                          :jsonb
#  client_signature(The signature of the agent)                                           :text
#  current_activity(Current agent activity state (e.g., cracking, waiting, benchmarking)) :string           indexed
#  current_hash_rate(Current hash rate in H/s, updated from HashcatStatus)                :decimal(20, 2)   default(0.0)
#  current_temperature(Current device temperature in Celsius, updated from HashcatStatus) :integer          default(0)
#  current_utilization(Current device utilization percentage, updated from HashcatStatus) :integer          default(0)
#  custom_label(Custom label for the agent)                                               :string           uniquely indexed
#  devices(Devices that the agent supports)                                               :string           default([]), is an Array
#  enabled(Is the agent active)                                                           :boolean          default(TRUE), not null
#  host_name(Name of the agent)                                                           :string           default(""), not null
#  last_ipaddress(Last known IP address)                                                  :string           default("")
#  last_seen_at(Last time the agent checked in)                                           :datetime         indexed => [state]
#  metrics_updated_at(Timestamp of last metrics update for throttling)                    :datetime         indexed
#  operating_system(Operating system of the agent)                                        :integer          default("unknown")
#  state(The state of the agent)                                                          :string           default("pending"), not null, indexed, indexed => [last_seen_at]
#  token(Token used to authenticate the agent)                                            :string(24)       uniquely indexed
#  created_at                                                                             :datetime         not null
#  updated_at                                                                             :datetime         not null
#  user_id(The user that the agent is associated with)                                    :bigint           not null, indexed
#
# Indexes
#
#  index_agents_on_current_activity        (current_activity)
#  index_agents_on_custom_label            (custom_label) UNIQUE
#  index_agents_on_metrics_updated_at      (metrics_updated_at)
#  index_agents_on_state                   (state)
#  index_agents_on_state_and_last_seen_at  (state,last_seen_at)
#  index_agents_on_token                   (token) UNIQUE
#  index_agents_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Agent < ApplicationRecord
  include ActiveSupport::NumberHelper
  include SafeBroadcasting
  include StoreModel::NestedAttributes

  # Hash rate units map for formatting display values.
  # Uses standard hash rate conventions (H/s, kH/s, MH/s, GH/s, TH/s, PH/s).
  HASH_RATE_UNITS = {
    unit: "H/s",
    thousand: "kH/s",
    million: "MH/s",
    billion: "GH/s",
    trillion: "TH/s",
    quadrillion: "PH/s"
  }.freeze

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

  validates :host_name, presence: true, length: { maximum: 255 }
  validates :custom_label, length: { maximum: 255 }, uniqueness: true, allow_nil: true
  validates :current_activity, length: { maximum: 50 }, allow_nil: true

  scope :active, -> { where(state: :active) }
  scope :inactive_for, ->(time) { where(last_seen_at: ...time.ago) }
  default_scope { order(:created_at) }

  # Broadcast tab-specific updates instead of full page refresh
  # This prevents resetting the active tab state when agent data changes
  after_update_commit :broadcast_tab_updates, unless: -> { Rails.env.test? }

  # Broadcasts updates to individual tab streams instead of the root agent stream.
  # This allows each tab panel to update independently without affecting the active tab state.
  def broadcast_tab_updates
    broadcast_replace_later_to [self, :overview],
      target: ActionView::RecordIdentifier.dom_id(self, :overview),
      partial: "agents/overview_tab",
      locals: { agent: self }

    broadcast_replace_later_to [self, :configuration],
      target: ActionView::RecordIdentifier.dom_id(self, :configuration),
      partial: "agents/configuration_tab",
      locals: { agent: self }

    broadcast_replace_later_to [self, :capabilities],
      target: ActionView::RecordIdentifier.dom_id(self, :capabilities),
      partial: "agents/capabilities_tab",
      locals: { agent: self }
  end

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
      Rails.logger.info(
        "[AgentLifecycle] shutdown: agent_id=#{agent.id} state_change=#{agent.state_was}->offline " \
        "running_tasks_abandoned=#{agent.tasks.with_states(:running).count} timestamp=#{Time.zone.now}"
      )
      agent.tasks.with_states(:running).each { |task| task.abandon }
    end

    after_transition on: :activate do |agent|
      Rails.logger.info(
        "[AgentLifecycle] connect: agent_id=#{agent.id} state_change=#{agent.state_was}->active " \
        "last_seen_at=#{agent.last_seen_at} ip=#{agent.last_ipaddress} timestamp=#{Time.zone.now}"
      )
    end

    after_transition on: :deactivate do |agent|
      Rails.logger.info(
        "[AgentLifecycle] disconnect: agent_id=#{agent.id} state_change=#{agent.state_was}->stopped " \
        "last_seen_at=#{agent.last_seen_at} ip=#{agent.last_ipaddress} timestamp=#{Time.zone.now}"
      )
    end

    after_transition on: :benchmarked do |agent|
      Rails.logger.info(
        "[AgentLifecycle] benchmark_complete: agent_id=#{agent.id} state_change=#{agent.state_was}->#{agent.state} " \
        "benchmark_count=#{agent.hashcat_benchmarks.count} timestamp=#{Time.zone.now}"
      )
    end

    after_transition on: :heartbeat do |agent|
      if agent.state_was == "offline"
        Rails.logger.info(
          "[AgentLifecycle] reconnect: agent_id=#{agent.id} state_change=offline->#{agent.state} " \
          "last_seen_at=#{agent.last_seen_at} ip=#{agent.last_ipaddress} timestamp=#{Time.zone.now}"
        )
      end
    end

    after_transition on: :check_online do |agent|
      if agent.offline?
        Rails.logger.warn(
          "[AgentLifecycle] heartbeat_timeout: agent_id=#{agent.id} state_change=#{agent.state_was}->offline " \
          "last_seen_at=#{agent.last_seen_at} threshold=#{ApplicationConfig.agent_considered_offline_time} timestamp=#{Time.zone.now}"
        )
      end
    end

    after_transition on: :check_benchmark_age do |agent|
      if agent.pending? && agent.state_was == "active"
        Rails.logger.info(
          "[AgentLifecycle] benchmark_stale: agent_id=#{agent.id} state_change=active->pending " \
          "last_benchmark_date=#{agent.last_benchmark_date} max_benchmark_age=#{ApplicationConfig.max_benchmark_age} " \
          "timestamp=#{Time.zone.now}"
        )
      end
    end

    event :check_online do
      # If the agent has NOT checked in within the configured offline threshold, mark it as offline.
      transition any => :offline if ->(agent) { agent.last_seen_at < ApplicationConfig.agent_considered_offline_time.ago }
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

  # Sets the advanced configuration for the agent.
  #
  # This method assigns a value to the `advanced_configuration` attribute.
  # If the provided value is a String, it attempts to parse it as JSON.
  # Otherwise, it directly assigns the value.
  #
  # @param value [String, Hash] The value to assign to advanced configuration.
  #   If a String is provided, it should contain valid JSON data.
  #
  # @return [void]
  def advanced_configuration=(value)
    self[:advanced_configuration] = value.is_a?(String) ? JSON.parse(value) : value
  end

  # Aggregates benchmark data for the agent.
  #
  # This method processes the most recent benchmark records associated with the agent.
  # It combines the hash speeds of benchmarks grouped by hash type and formats
  # the summarized results into descriptive strings.
  # If there are no recent benchmarks, or grouped summaries are not available, it returns nil.
  #
  # @return [Array<String>, nil] A collection of formatted benchmark summaries.
  #   Each summary describes the hash type and its aggregated speed.
  #   Returns nil if there are no benchmarks to process.
  def aggregate_benchmarks
    return nil if last_benchmarks.blank?
    benchmark_summaries = last_benchmarks&.group(:hash_type)&.sum(:hash_speed)
    return nil if benchmark_summaries.blank?
    benchmark_summaries.map { |hash_type, speed| format_benchmark_summary(hash_type, speed) }
  end

  # Retrieves the allowed hash types for the agent.
  #
  # This method queries the associated `hashcat_benchmarks` for unique hash types.
  # It returns a list of distinct hash types supported by the agent, based on its stored benchmark data.
  #
  # @return [Array<String>] An array containing distinct hash types supported by the agent.
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

  def current_running_attack
    tasks.running.first&.attack
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

  # Checks if the agent meets the minimum performance benchmark for a specific hash type.
  #
  # This method calculates the total hash speed for the agent for the given hash type
  # and compares it to the minimum performance benchmark defined in the application configuration.
  #
  # @param hash_type [Integer] The hash type to check the performance benchmark for.
  # @return [Boolean] true if the agent meets or exceeds the minimum performance benchmark, false otherwise.
  def meets_performance_threshold?(hash_type)
    total_hash_speed = hashcat_benchmarks.where(hash_type: hash_type).sum(:hash_speed)
    total_hash_speed >= ApplicationConfig.min_performance_benchmark
  end

  # Returns the name of the agent.
  #
  # If a custom label is set, it returns the custom label.
  # Otherwise, it returns the host name.
  #
  # @return [String] The name of the agent.
  def name
    custom_label.presence || host_name
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
    TaskAssignmentService.new(self).find_next_task
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

  # Returns a formatted hash rate display string.
  #
  # - Returns "—" if current_hash_rate is nil
  # - Returns "0 H/s" if current_hash_rate is zero
  # - Returns formatted hash rate with proper units (e.g., "123.45 MH/s") for positive values
  #
  # @return [String] A formatted hash rate string suitable for display
  def hash_rate_display
    return "—" if current_hash_rate.nil?
    return "0 H/s" if current_hash_rate.zero?

    number_to_human(
      current_hash_rate,
      significant: false,
      units: HASH_RATE_UNITS,
      format: "%n %u"
    )
  end
end
