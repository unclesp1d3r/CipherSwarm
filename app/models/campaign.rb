# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Campaign class represents a marketing or operational initiative
# managed within a project. It includes priority-based execution,
# associations with related models, and status tracking.
#
# This model uses soft deletes, validations, scopes,
# and provides several utility methods for state management and
# priority handling.
#
# Notable Features:
# - Priority-based campaign management with defined enum values.
# - Associations with `hash_list`, `project`, `attacks`, and `tasks`.
# - Broadcasts updates to clients (except in test environments).
# - Callback methods to orchestrate priority-dependent campaign state transitions.
#
# Instance Methods:
# - `attack_count_label` - Summary label for incomplete vs total attacks.
# - `completed?` - Checks whether all attacks or associated hashes are complete.
# - `hash_count_label` - Summary label for cracked vs total hash items.
# - `pause` - Pauses associated attacks.
# - `paused?` - Determines if the campaign is paused based on attack states.
# - `priority_to_emoji` - Provides an emoji representation of the campaign priority.
# - `resume` - Resumes paused attacks associated with the campaign.
#
# Class Methods:
# - `pause_lower_priority_campaigns` - Pauses campaigns with lower priority and resumes those with the highest priority.
# == Schema Information
#
# Table name: campaigns
#
#  id                                                                                                     :bigint           not null, primary key
#  attacks_count                                                                                          :integer          default(0), not null
#  deleted_at                                                                                             :datetime         indexed
#  description                                                                                            :text
#  name                                                                                                   :string           not null
#  priority( -1: Deferred, 0: Routine, 1: Priority, 2: Urgent, 3: Immediate, 4: Flash, 5: Flash Override) :integer          default("routine"), not null
#  created_at                                                                                             :datetime         not null
#  updated_at                                                                                             :datetime         not null
#  hash_list_id                                                                                           :bigint           not null, indexed
#  project_id                                                                                             :bigint           not null, indexed
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
  # When a campaign exists in the system with a priority, all campaigns of lower priority are paused until the campaign is completed.
  #
  # The priority can be one of the following values:
  # - `deferred`: -1 (best effort, runs when no other campaigns are running)
  # - `routine`: 0 (default)
  # - `priority`: 1 (Important, but not urgent)
  # - `urgent`: 2 (Important and urgent)
  # - `immediate`: 3 (Immediate, must be run as soon as possible)
  # - `flash`: 4 (Critical and should only include a small number of hashes with simple attacks)
  # - `flash_override`: 5 (Restricted to admin users only)
  #
  # @return [Hash] the priority enum hash.
  enum :priority, { deferred: -1, routine: 0, priority: 1, urgent: 2, immediate: 3, flash: 4, flash_override: 5 }

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
  default_scope { in_order_of(:priority, %i[flash_override flash immediate urgent priority routine deferred]).order(:created_at) }
  scope :completed, -> { joins(:attacks).where(attacks: { state: :completed }) }
  scope :active, -> { joins(:attacks).where(attacks: { state: %i[running paused pending] }) }
  scope :in_projects, ->(ids) { where(project_id: ids) }

  # Delegations
  delegate :uncracked_count, :cracked_count, :hash_item_count, to: :hash_list

  # Broadcasts a refresh to the client when the campaign is updated unless running in test environment
  broadcasts_refreshes unless Rails.env.test?

  # Callbacks
  after_commit :check_and_pause_lower_priority_campaigns, on: %i[create update]
  after_commit :mark_attacks_complete, on: [:update]

  # Pauses all campaigns with a priority lower than the maximum priority and resumes all campaigns with the maximum priority.
  #
  # This method performs the following steps:
  # 1. Finds the maximum priority of all active campaigns in the system.
  # 2. Pauses all campaigns that have a priority lower than the maximum priority.
  # 3. Resumes all campaigns that have the maximum priority.
  #
  # @return [void]
  def self.pause_lower_priority_campaigns
    max_priority = Campaign.active.maximum(:priority)
    Campaign.where(priority: ...max_priority).find_each(&:pause)
    Campaign.where(priority: max_priority).find_each(&:resume)
  end

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
  #   - "routine" => "🔄"
  #   - "priority" => "🔵"
  #   - "urgent" => "🟠"
  #   - "immediate" => "🔴"
  #   - "flash" => "🟡"
  #   - "flash_override" => "🔒"
  #   - any other value => "❓"
  def priority_to_emoji
    case priority
    when "deferred"
      "🕰"
    when "routine"
      "🔄"
    when "priority"
      "🔵"
    when "urgent"
      "🟠"
    when "immediate"
      "🔴"
    when "flash"
      "🟡"
    when "flash_override"
      "🔒"
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

  private

  # This method checks and pauses campaigns with lower priority.
  # It calls the class method `pause_lower_priority_campaigns` on the `Campaign` model.
  #
  # @return [void]
  def check_and_pause_lower_priority_campaigns
    self.class.pause_lower_priority_campaigns
  end

  # Marks all attacks as complete if the campaign is completed.
  # This is skipped in test environments to avoid interfering with unit tests.
  #
  # @return [void]
  def mark_attacks_complete
    return if Rails.env.test?
    attacks.without_state(:completed).each(&:complete) if completed?
  end
end
