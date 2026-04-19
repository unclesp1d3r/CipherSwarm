# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Manages hash cracking campaigns with priority-based execution.
#
# @soft_delete
# - Uses Discard::Model; destroy is overridden to soft-delete (set deleted_at)
#   while still running destroy callbacks so `dependent: :destroy` cascades.
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
# - quarantined: campaigns flagged with unrecoverable errors
# - not_quarantined: campaigns not flagged as quarantined
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
# - `clear_quarantine!` - Removes quarantine flag and reason.
# - `completed?` - Checks whether all attacks or associated hashes are complete.
# - `hash_count_label` - Summary label for cracked vs total hash items.
# - `pause` - Pauses associated attacks.
# - `paused?` - Determines if the campaign is paused based on attack states.
# - `priority_to_emoji` - Provides an emoji representation of the campaign priority.
# - `quarantine!(reason)` - Flags campaign as quarantined with a reason.
# - `quarantined?` - Returns whether the campaign is currently quarantined.
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
#  quarantine_reason                              :text
#  quarantined                                    :boolean          default(FALSE), not null, indexed
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
#  index_campaigns_on_quarantined              (quarantined) WHERE (quarantined = true)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
class Campaign < ApplicationRecord
  include Discard::Model
  # Explicit even though :deleted_at is Discard's default — keeps the intent
  # visible and guards against upstream default changes. The column itself is
  # the one paranoia used, reused to avoid a schema migration.
  self.discard_column = :deleted_at
  # Preserves paranoia's implicit filter so every Campaign query keeps hiding
  # soft-deleted rows by default. Use `.unscoped` to reach discarded records.
  default_scope -> { kept }

  # Default_scope combines its `deleted_at IS NULL` clause with Discard's
  # built-in `.discarded` (which adds `deleted_at IS NOT NULL`), producing
  # an always-empty set. Removing only the deleted_at predicate restores
  # the expected behavior while leaving any future default_scope additions
  # intact.
  scope :discarded, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }

  # Broadcasts targeted updates to the client when the campaign is updated unless running in test environment
  include SafeBroadcasting

  # Preserve paranoia's destroy-means-soft-delete contract: `destroy` runs the
  # standard destroy callbacks (so `dependent: :destroy` cascades to children
  # and `before_destroy` / `after_destroy` hooks still fire) but replaces the
  # DELETE with `discard` (sets deleted_at). The `discarded?` guard makes a
  # second `destroy` call a no-op so cascades never fire twice.
  def destroy
    return self if discarded?
    with_transaction_returning_status do
      run_callbacks(:destroy) { discard }
    end
    self
  end

  def destroy!
    destroy
    raise ActiveRecord::RecordNotDestroyed.new("Failed to discard #{self.class}", self) unless discarded?
    self
  end

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
  scope :quarantined, -> { where(quarantined: true) }
  scope :not_quarantined, -> { where(quarantined: false) }

  # Delegations
  delegate :uncracked_count, :cracked_count, :hash_item_count, to: :hash_list


  # Callbacks
  after_commit :mark_attacks_complete, on: [:update]
  after_commit :broadcast_eta_update, on: [:update], if: :should_broadcast_eta?
  after_commit :trigger_priority_rebalance_if_needed, on: [:update]

  # Provides a label indicating the number of incomplete attacks out of the total number of attacks.
  #
  # @return [String] the label showing incomplete and total attacks.
  def attack_count_label
    # PERFORMANCE: Use counter cache column for total, SQL COUNT only for incomplete subset
    "#{attacks.awaiting_assignment.count} / #{attacks_count}"
  end

  # Removes the quarantine flag and clears the reason.
  #
  # @return [true] always returns true on success.
  # @raise [ActiveRecord::RecordInvalid] if the update fails validation.
  def clear_quarantine!
    update!(quarantined: false, quarantine_reason: nil)
  end

  # Checks if the campaign is completed.
  #
  # A campaign is considered completed if all the hash items in the hash list have been cracked
  # or all the attacks associated with the campaign are in the completed state.
  #
  # @return [Boolean] true if the campaign is completed, false otherwise.
  def completed?
    # PERFORMANCE: Use .exists? with negation and preserve short-circuit evaluation
    # to avoid running the second query if the first condition is already true.
    # .exists? returns boolean directly, .empty? must check for presence
    return true unless hash_list.uncracked_items.exists?

    !attacks.without_state(:completed).exists?
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
  # PERFORMANCE: Single query instead of two — counts attacks by state bucket in one pass.
  def paused?
    return false if attacks_count.zero?

    states = attacks.group(:state).count
    has_paused = (states["paused"] || 0).positive?
    all_settled = states.keys.all? { |s| %w[paused completed].include?(s) }
    has_paused && all_settled
  end

  # Maps the campaign's priority to an emoji representation.
  #
  # @return [String] the emoji for the campaign's priority:
  #   "🕰" for deferred, "🔄" for normal, "🔴" for high, "❓" for unknown.
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

  # Flags the campaign as quarantined with the given reason.
  #
  # @param reason [String] a description of why the campaign was quarantined.
  # @return [true] always returns true on success.
  # @raise [ActiveRecord::RecordInvalid] if the update fails validation.
  def quarantine!(reason)
    update!(quarantined: true, quarantine_reason: reason)
  end

  # Returns whether this campaign is currently quarantined.
  #
  # Delegates to the ActiveRecord-generated predicate for the `quarantined` boolean column.
  # Explicitly defined here to document the intended model API and make the quarantine
  # lifecycle methods discoverable as a cohesive set: quarantine!, clear_quarantine!, quarantined?
  #
  # @return [Boolean] true if the campaign is quarantined, false otherwise.
  def quarantined?
    super
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

  # Calculates the current ETA for running attacks without caching.
  #
  # Returns the maximum estimated finish time among all currently running tasks.
  # This bypasses the cache to provide a fresh calculation.
  #
  # @return [Time, nil] the max ETA of running attacks, or nil if none are running
  # @see CampaignEtaCalculator#current_eta
  def calculate_current_eta
    CampaignEtaCalculator.new(self, cache: false).current_eta
  end

  # Calculates the total ETA for all incomplete attacks without caching.
  #
  # Estimates total completion time by combining running attack ETAs with
  # complexity-based estimates for pending/paused attacks.
  # This bypasses the cache to provide a fresh calculation.
  #
  # @return [Time, nil] the estimated total completion time, or nil if no incomplete attacks
  # @see CampaignEtaCalculator#total_eta
  def calculate_total_eta
    CampaignEtaCalculator.new(self, cache: false).total_eta
  end

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
  # PERFORMANCE: Short-circuit with counter cache before running expensive queries.
  # Most touch-cascaded updates (from HashItem → HashList → Campaign) don't change
  # attack states, so the counter cache check avoids 2 existence queries per touch.
  #
  # @return [void]
  def mark_attacks_complete
    return if attacks_count.zero?
    return unless completed?

    attacks.without_state(:completed).find_each do |attack|
      attack.complete if attack.can_complete?
    rescue StateMachines::InvalidTransition => e
      Rails.logger.warn("[Campaign #{id}] Failed to complete attack #{attack.id}: #{e.message}")
    end
  end

  # Only broadcast ETA when meaningful data changes — not on every cascading touch.
  # Priority changes, attack count changes, and quarantine state changes affect ETA display.
  def should_broadcast_eta?
    saved_change_to_priority? ||
      saved_change_to_attacks_count? ||
      saved_change_to_quarantined?
  end

  # Enqueues a task preemption rebalance when the campaign's priority is raised.
  #
  # Only fires when priority increases (e.g. normal → high), not on decreases or
  # unchanged saves. Uses Campaign.priorities to compare integer values of the
  # old and new priority strings returned by saved_change_to_priority.
  #
  # @return [void]
  def trigger_priority_rebalance_if_needed
    return unless saved_change_to_priority?

    old_priority, new_priority = saved_change_to_priority
    old_value = Campaign.priorities[old_priority]
    new_value = Campaign.priorities[new_priority]

    return if old_value.nil? || new_value.nil?
    return unless new_value > old_value

    begin
      CampaignPriorityRebalanceJob.perform_later(id)
    rescue StandardError => e
      Rails.logger.error(
        "[Campaign##{id}] Failed to enqueue priority rebalance: #{e.class} - #{e.message} - " \
        "Backtrace: #{Array(e.backtrace).first(5).join(' | ')}"
      )
      # Don't re-raise in after_commit — the save already succeeded; the periodic
      # rebalance in UpdateStatusJob will catch up.
    end
  end
end
