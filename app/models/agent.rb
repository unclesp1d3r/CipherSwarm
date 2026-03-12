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
  include Agent::Benchmarking
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

  # Fields whose changes should trigger a configuration tab broadcast.
  CONFIGURATION_BROADCAST_FIELDS = %w[
    enabled client_signature last_ipaddress advanced_configuration
    custom_label operating_system
  ].freeze

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
  validate :devices_length_within_limit

  scope :active, -> { where(state: :active) }
  scope :inactive_for, ->(time) { where(last_seen_at: ...time.ago) }

  self.implicit_order_column = :created_at

  # Broadcast tab-specific updates instead of full page refresh
  # This prevents resetting the active tab state when agent data changes
  after_update_commit :broadcast_tab_updates, :broadcast_index_state, :broadcast_index_last_seen

  # Replaces just the state pill on index cards when the agent's state transitions.
  # Index cards subscribe to the bare agent stream via turbo_stream_from(agent).
  # Only fires on state transitions to avoid excessive updates from heartbeats.
  def broadcast_index_state
    return unless saved_change_to_state?

    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :index_state),
      partial: "agents/index_state",
      locals: { agent: self }
  end

  # Replaces just the "Last Seen" value on index cards when last_seen_at changes.
  def broadcast_index_last_seen
    return unless saved_change_to_last_seen_at?

    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :index_last_seen),
      partial: "agents/index_last_seen",
      locals: { agent: self }
  end


  # Broadcasts updates to individual tab streams instead of the root agent stream.
  # This allows each tab panel to update independently without affecting the active tab state.
  #
  # Overview: always broadcast (last_seen, state, metrics change frequently).
  # Configuration: only when config-relevant fields change.
  # Capabilities: only when state changes (benchmark data arrives via state transitions).
  def broadcast_tab_updates
    broadcast_replace_later_to [self, :overview],
      target: ActionView::RecordIdentifier.dom_id(self, :overview),
      partial: "agents/overview_tab",
      locals: { agent: self }

    if saved_changes.keys.intersect?(CONFIGURATION_BROADCAST_FIELDS)
      broadcast_replace_later_to [self, :configuration],
        target: ActionView::RecordIdentifier.dom_id(self, :configuration),
        partial: "agents/configuration_tab",
        locals: { agent: self }
    end

    return unless saved_change_to_state?
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
      running_tasks = agent.tasks.with_states(:running).includes(:attack)
      paused_count = running_tasks.count

      Rails.logger.info(
        "[AgentLifecycle] shutdown: agent_id=#{agent.id} state_change=#{agent.state_was}->offline " \
        "running_tasks_paused=#{paused_count} timestamp=#{Time.zone.now}"
      )

      affected_attacks = Set.new
      running_tasks.find_each do |task|
        paused = false
        begin
          if task.can_pause?
            task.pause!
            paused = true
          end
        rescue StateMachines::InvalidTransition, ActiveRecord::StaleObjectError => e
          Rails.logger.error(
            "[AgentLifecycle] shutdown: Failed to pause task #{task.id} " \
            "for agent #{agent.id}: #{e.class} - #{e.message}"
          )
        end
        # Only clear claim fields on successfully paused tasks.
        # Running tasks with cleared claims would be an inconsistent state
        # not handled by any recovery path. If pause failed, the heartbeat
        # timeout will eventually detect the agent as offline and handle the task.
        if paused
          task.update_columns(claimed_by_agent_id: nil, claimed_at: nil, expires_at: nil) # rubocop:disable Rails/SkipsModelValidations
        end
        affected_attacks << task.attack
      end

      # Pause attacks that have no remaining in-progress tasks (pending or running).
      # This updates the Activity page to reflect that work has stopped.
      affected_attacks.each do |attack|
        next unless attack.can_pause?
        next if attack.tasks.without_states(:paused, :completed, :exhausted, :failed).exists?

        begin
          attack.pause!
        rescue StateMachines::InvalidTransition, ActiveRecord::StaleObjectError => e
          Rails.logger.error(
            "[AgentLifecycle] shutdown: Failed to pause attack #{attack.id} " \
            "for agent #{agent.id}: #{e.class} - #{e.message}"
          )
        end
      end
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

  def current_running_attack
    tasks.running.includes(:attack).order(:id).first&.attack
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

  # Returns an array of project IDs associated with the agent.
  #
  # @return [Array<Integer>] an array of project IDs
  def project_ids
    Rails.cache.fetch("#{cache_key_with_version}/project_ids", expires_in: 1.hour) do
      projects.pluck(:id)
    end
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

  private

  def devices_length_within_limit
    errors.add(:devices, "must have at most 64 entries") if devices.present? && devices.length > 64
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
