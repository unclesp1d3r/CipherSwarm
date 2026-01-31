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
# None (priority-based task assignment handled by TaskPreemptionService)
#
# == Schema Information
#
# Table name: campaigns
#
#  id                                             :bigint           not null, primary key
#  attacks_count                                  :integer          default(0), not null
#  deleted_at                                     :datetime         indexed
#  description                                    :text
#  name                                           :string           not null
#  priority(-1: Deferred, 0: Normal, 2: High)     :integer          default("normal"), not null, indexed, indexed => [project_id]
#  created_at                                     :datetime         not null
#  updated_at                                     :datetime         not null
#  creator_id(The user who created this campaign) :bigint           indexed
#  hash_list_id                                   :bigint           not null, indexed
#  project_id                                     :bigint           not null, indexed, indexed => [priority]
#
# Indexes
#
#  index_campaigns_on_creator_id               (creator_id)
#  index_campaigns_on_deleted_at               (deleted_at)
#  index_campaigns_on_hash_list_id             (hash_list_id)
#  index_campaigns_on_priority                 (priority)
#  index_campaigns_on_project_id               (project_id)
#  index_campaigns_on_project_id_and_priority  (project_id,priority)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
class Campaign < ApplicationRecord
  acts_as_paranoid # Soft deletes the campaign.

  # Priority enum for the campaign.
  #
  # The priority determines task assignment order and preemption behavior:
  # - Higher priority campaigns receive tasks before lower priority ones
  # - High/normal priority campaigns can preempt lower priority running tasks
  # - Deferred campaigns never trigger preemption, running only when capacity available
  #
  # Priority values:
  # - `deferred`: -1 (best effort, runs when capacity available, never preempts)
  # - `normal`: 0 (default priority for regular campaigns, can preempt deferred)
  # - `high`: 2 (important campaigns, can preempt normal/deferred, restricted to admins)
  #
  # Access control:
  # - All users can create deferred/normal campaigns
  # - Only project admins/owners and global admins can create high priority campaigns
  #   (enforced by CampaignsHelper#available_priorities_for and controller authorization)
  #
  # @return [Hash] the priority enum hash.
  enum :priority, { deferred: -1, normal: 0, high: 2 }

  # Associations
  belongs_to :hash_list, touch: true
  belongs_to :project, touch: true
  belongs_to :creator, class_name: "User", optional: true
  has_many :attacks, dependent: :destroy
  has_many :tasks, through: :attacks, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :priority, presence: true
  validates_associated :hash_list
  validates_associated :project

  # Scopes
  scope :by_priority, -> { in_order_of(:priority, %i[high normal deferred]).order(:created_at) }
  scope :completed, -> { joins(:attacks).where(attacks: { state: :completed }) }
  scope :active, -> { joins(:attacks).where(attacks: { state: %i[running paused pending] }) }
  scope :in_projects, ->(ids) { where(project_id: ids) }

  # Delegations
  delegate :uncracked_count, :cracked_count, :hash_item_count, to: :hash_list

  # Broadcasts targeted updates to the client when the campaign is updated unless running in test environment
  include SafeBroadcasting

  # Callbacks
  after_commit :mark_attacks_complete, on: [:update]
  after_commit :broadcast_eta_update, on: [:update]

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
  ##
  # Maps the campaign's priority to a single emoji representing that priority.
  # @return [String] The emoji for the campaign's priority: "🕰" for deferred, "🔄" for normal, "🔴" for high, "❓" for any other or unknown value.
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

  # Returns the estimated time to complete currently running attacks.
  #
  # Delegates to CampaignEtaCalculator service for calculation with caching.
  #
  # @return [Time, nil] The maximum estimated finish time among running attacks, or nil if no running attacks
  # @see CampaignEtaCalculator#current_eta
  delegate :current_eta, to: :eta_calculator

  # Returns the estimated total time to complete all incomplete attacks.
  #
  # Delegates to CampaignEtaCalculator service for calculation with caching.
  #
  # @return [Time, nil] The total estimated completion time, or nil if no incomplete attacks
  # @see CampaignEtaCalculator#total_eta
  delegate :total_eta, to: :eta_calculator

  # Returns the ETA calculator service for this campaign.
  #
  # @return [CampaignEtaCalculator] the calculator instance
  def eta_calculator
    @eta_calculator ||= CampaignEtaCalculator.new(self)
  end

  def broadcast_eta_update
    Rails.logger.info("[BroadcastUpdate] Campaign #{id} - Broadcasting ETA update")
    broadcast_replace_to(
      self,
      target: "eta_summary",
      partial: "campaigns/eta_summary",
      locals: { campaign: self }
    )
  end

  def broadcast_recent_cracks_update
    Rails.logger.info("[BroadcastUpdate] Campaign #{id} - Broadcasting recent cracks update")
    broadcast_replace_to(
      self,
      target: "recent_cracks",
      partial: "campaigns/recent_cracks",
      locals: { campaign: self }
    )
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
