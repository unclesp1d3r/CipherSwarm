# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Manages hash cracking campaigns with priority-based execution.
#
# @acts_as
# - paranoid: enables soft deletes
#
# @enums
# - priority:
#   - deferred (-1): best effort, runs when no other campaigns are running
#   - normal (0): default priority
#   - high (2): important campaigns, restricted to project admins
#
# @relationships
# - belongs_to :hash_list, :project (touch: true)
# - has_many :attacks, :tasks (through attacks, dependent: destroy)
#
# @validations
# - name: present
# - priority: present
# - hash_list, project: valid associations
#
# @scopes
# - default: ordered by priority and created_at
# - completed: attacks in completed state
# - active: attacks in running/paused/pending state
# - in_projects: by project IDs
#
# @callbacks
# - after_commit: manage priority-based campaign execution
#
# @notable_features
# - Priority-based campaign management with defined enum values.
# - Associations with `hash_list`, `project`, `attacks`, and `tasks`.
# - Broadcasts updates to clients (except in test environments).
# - Callback methods to orchestrate priority-dependent campaign state transitions.
#
# @instance_methods
# - `attack_count_label` - Summary label for incomplete vs total attacks.
# - `completed?` - Checks whether all attacks or associated hashes are complete.
# - `hash_count_label` - Summary label for cracked vs total hash items.
# - `pause` - Pauses associated attacks.
# - `paused?` - Determines if the campaign is paused based on attack states.
# - `priority_to_emoji` - Provides an emoji representation of the campaign priority.
# - `resume` - Resumes paused attacks associated with the campaign.
#
# @class_methods
# - `pause_lower_priority_campaigns` - Pauses campaigns with lower priority and resumes those with the highest priority.
#
# == Schema Information
#
# Table name: campaigns
#
#  id                                         :bigint           not null, primary key
#  attacks_count                              :integer          default(0), not null
#  deleted_at                                 :datetime         indexed
#  description                                :text
#  name                                       :string           not null
#  priority(-1: Deferred, 0: Normal, 2: High) :integer          default("normal"), not null
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  hash_list_id                               :bigint           not null, indexed
#  project_id                                 :bigint           not null, indexed
#
# Indexes
#
#  index_campaigns_on_deleted_at    (deleted_at)
#  index_campaigns_on_hash_list_id  (hash_list_id)
#  index_campaigns_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
class Campaign < ApplicationRecord
  acts_as_paranoid # Soft deletes the campaign.

  # Priority enum for the campaign.
  #
  # The priority enum is used to determine the priority of the campaign.
  # Higher priority campaigns receive preferential task assignment and may preempt lower priority tasks.
  #
  # The priority can be one of the following values:
  # - `deferred`: -1 (best effort, runs when capacity available)
  # - `normal`: 0 (default priority for regular campaigns)
  # - `high`: 2 (important campaigns, restricted to project admins/owners)
  #
  # @return [Hash] the priority enum hash.
  enum :priority, { deferred: -1, normal: 0, high: 2 }

  # Associations
  belongs_to :hash_list, touch: true
  belongs_to :project, touch: true
  has_many :attacks, dependent: :destroy
  has_many :tasks, through: :attacks, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :priority, presence: true
  validates_associated :hash_list
  validates_associated :project

  # Scopes
  default_scope { in_order_of(:priority, %i[high normal deferred]).order(:created_at) }
  scope :completed, -> { joins(:attacks).where(attacks: { state: :completed }) }
  scope :active, -> { joins(:attacks).where(attacks: { state: %i[running paused pending] }) }
  scope :in_projects, ->(ids) { where(project_id: ids) }

  # Delegations
  delegate :uncracked_count, :cracked_count, :hash_item_count, to: :hash_list

  # Broadcasts a refresh to the client when the campaign is updated unless running in test environment
  include SafeBroadcasting

  broadcasts_refreshes unless Rails.env.test?

  # Callbacks
  after_commit :mark_attacks_complete, on: [:update]

  # Provides a label indicating the number of incomplete attacks out of the total number of attacks.
  #
  # @return [String] the label showing incomplete and total attacks.
  def attack_count_label
    "#{attacks.incomplete.size} / #{attacks.size}"
  end

  # Checks if the campaign is completed.
  #
  # A campaign is considered completed if all the hash items in the hash list have been cracked
  # or all the attacks associated with the campaign are in the completed state.
  #
  # @return [Boolean] true if the campaign is completed, false otherwise.
  def completed?
    uncracked_items_empty = hash_list.uncracked_items.empty?
    all_attacks_completed = attacks.without_state(:completed).empty?

    uncracked_items_empty || all_attacks_completed
  end

  # Provides a label indicating the number of cracked hashes out of the total number of hash items.
  #
  # @return [String] the label showing cracked and total hashes.
  def hash_count_label
    "#{cracked_count} of #{hash_item_count}"
  end

  # Pauses all associated attacks for the campaign.
  # Iterates through each attack associated with the campaign and calls the `pause` method on it.
  #
  # @return [void]
  def pause
    attacks.active.find_each(&:pause)
  end

  # Checks if the campaign is paused.
  #
  # A campaign is considered paused if all its attacks are either paused or completed,
  # and there is at least one attack in the paused state.
  #
  # @return [Boolean] true if the campaign is paused, false otherwise.
  def paused?
    attacks.without_states(%i[paused completed]).empty? && attacks.with_state(:paused).any?
  end

  # Converts the campaign's priority to a corresponding emoji.
  #
  # @return [String] the emoji representing the campaign's priority.
  #   - "deferred" => "🕰"
  #   - "normal" => "🔄"
  #   - "high" => "🔴"
  #   - any other value => "❓"
  def priority_to_emoji
    case priority
    when "deferred"
      "🕰"
    when "normal"
      "🔄"
    when "high"
      "🔴"
    else
      "❓"
    end
  end

  # Resumes all attacks associated with the campaign.
  # Iterates through each attack and calls the `resume` method on it.
  #
  # @return [void]
  def resume
    attacks.with_state(:paused).find_each(&:resume)
  end

  # Calculates the estimated time to complete currently running attacks.
  #
  # Queries running attacks and extracts the maximum estimated finish time from their running tasks.
  #
  # @return [Time, nil] The maximum estimated finish time among running attacks, or nil if no running attacks
  def calculate_current_eta
    running_attacks = attacks.with_state(:running)
    return nil if running_attacks.blank?

    # Find all running tasks from running attacks and get their estimated finish times
    running_tasks = Task.joins(:attack)
                        .where(attacks: { id: running_attacks.ids })
                        .with_state(:running)

    # Get the maximum estimated finish time from all running tasks
    max_eta = running_tasks.map(&:estimated_finish_time).compact.max
    max_eta
  end

  # Calculates the estimated total time to complete all incomplete attacks.
  #
  # Combines running attack ETAs with estimated time for pending/paused attacks
  # based on their complexity values and benchmark hash rates.
  #
  # @return [Time, nil] The total estimated completion time, or nil if no incomplete attacks
  def calculate_total_eta
    incomplete_attacks = attacks.incomplete

    return nil if incomplete_attacks.blank?

    # Get current ETA for running attacks as the baseline
    current_eta_time = calculate_current_eta

    # Find pending or paused attacks that need time estimation
    pending_or_paused_attacks = incomplete_attacks.with_states(:pending, :paused)

    # If no pending/paused attacks, return the current running ETA
    return current_eta_time if pending_or_paused_attacks.blank?

    # Calculate estimated additional time for pending/paused attacks
    additional_seconds = estimate_pending_attacks_duration(pending_or_paused_attacks)

    # If we have a current ETA baseline, add the additional time
    # Otherwise, use now + additional time as the baseline
    if current_eta_time.present?
      current_eta_time + additional_seconds.seconds
    elsif additional_seconds.positive?
      Time.current + additional_seconds.seconds
    end
  end

  # Returns the estimated time to complete currently running attacks.
  #
  # Uses Rails.cache with a 1-minute TTL for performance.
  #
  # @return [Time, nil] The maximum estimated finish time among running attacks, or nil if no running attacks
  def current_eta
    Rails.cache.fetch("#{cache_key_with_version}/current_eta", expires_in: 1.minute) do
      calculate_current_eta
    end
  end

  # Estimates the total duration for pending/paused attacks based on complexity and benchmark rates.
  #
  # For each attack, calculates: complexity_value / fastest_hash_rate_for_hash_type
  # Falls back to a default rate if no benchmarks exist.
  #
  # @param pending_attacks [ActiveRecord::Relation] Collection of pending/paused attacks
  # @return [Float] Estimated total seconds for all pending attacks
  def estimate_pending_attacks_duration(pending_attacks)
    total_seconds = 0.0

    pending_attacks.find_each do |attack|
      complexity = attack.complexity_value.to_f
      next if complexity.zero?

      # Get the fastest known hash rate for this attack's hash type
      hash_rate = fastest_hash_rate_for_attack(attack)
      next if hash_rate.nil? || hash_rate.zero?

      # Estimate time: complexity (keyspace) / hash_rate (H/s) = seconds
      estimated_seconds = complexity / hash_rate
      total_seconds += estimated_seconds
    end

    total_seconds
  end

  # Finds the fastest hash rate available for the given attack's hash type.
  #
  # Uses benchmarks from all agents to find the maximum throughput.
  #
  # @param attack [Attack] The attack to find hash rate for
  # @return [Float, nil] The fastest hash rate in H/s, or nil if no benchmarks exist
  def fastest_hash_rate_for_attack(attack)
    hash_mode = attack.hash_mode
    return nil if hash_mode.blank?

    # Find the fastest benchmark for this hash type
    fastest_benchmark = HashcatBenchmark.fastest_device_for_hash_type(hash_mode)
    fastest_benchmark&.hash_speed
  end

  # Returns the estimated total time to complete all incomplete attacks.
  #
  # Uses Rails.cache with a 1-minute TTL for performance.
  #
  # @return [Time, nil] The total estimated completion time, or nil if no incomplete attacks
  def total_eta
    Rails.cache.fetch("#{cache_key_with_version}/total_eta", expires_in: 1.minute) do
      calculate_total_eta
    end
  end

  private

  # Marks all attacks as complete if the campaign is completed.
  # This is skipped in test environments to avoid interfering with unit tests.
  #
  # @return [void]
  def mark_attacks_complete
    return if Rails.env.test?
    attacks.without_state(:completed).each(&:complete) if completed?
  end
end
