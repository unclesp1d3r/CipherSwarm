# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The Attack class represents a computational attack process within a campaign.
# It provides mechanisms to track progress, manage complexity, and interact
# with external cracking tools. The class offers both public and private methods
# to handle attack-specific logic including parameterization, execution, and
# result tracking.
#
# The class is part of the application's attack management system and operates
# within the context of a campaign.
#
# === Public Methods
# - completed?:
#   Determines whether the attack has been completed.
# - estimated_complexity:
#   Computes and returns the estimated complexity of the attack.
# - estimated_finish_time:
#   Calculates the predicted finish time of the attack based on current progress.
# - executing_agent:
#   Retrieves the agent responsible for executing the attack.
# - force_complexity_update:
#   Forces an update of the stored complexity value for the attack.
# - hashcat_parameters:
#   Generates and returns the necessary parameters for running the attack with Hashcat.
# - percentage_complete:
#   Calculates the percentage of progress completed for the attack.
# - progress_text:
#   Retrieves a text representation of the current progress state.
# - run_time:
#   Returns the total runtime of the attack process.
# - to_full_label:
#   Generates a full descriptive label for the attack.
# - to_label:
#   Produces a short label representation for the attack.
# - to_label_with_complexity:
#   Generates a label including details about the attack's complexity.
#
# == Schema Information
#
# Table name: attacks
#
#  id                                                                                                  :bigint           not null, primary key
#  attack_mode(Hashcat attack mode)                                                                    :integer          default("dictionary"), not null, indexed
#  classic_markov(Is classic Markov chain enabled?)                                                    :boolean          default(FALSE), not null
#  complexity_value(Complexity value of the attack)                                                    :decimal(, )      default(0.0), not null, indexed
#  custom_charset_1(Custom charset 1)                                                                  :string           default("")
#  custom_charset_2(Custom charset 2)                                                                  :string           default("")
#  custom_charset_3(Custom charset 3)                                                                  :string           default("")
#  custom_charset_4(Custom charset 4)                                                                  :string           default("")
#  deleted_at                                                                                          :datetime         indexed
#  description(Attack description)                                                                     :text             default("")
#  disable_markov(Is Markov chain disabled?)                                                           :boolean          default(FALSE), not null
#  end_time(The time the attack ended.)                                                                :datetime
#  increment_maximum(Hashcat increment maximum)                                                        :integer          default(0)
#  increment_minimum(Hashcat increment minimum)                                                        :integer          default(0)
#  increment_mode(Is the attack using increment mode?)                                                 :boolean          default(FALSE), not null
#  left_rule(Left rule)                                                                                :string           default("")
#  markov_threshold(Hashcat Markov threshold (e.g. 1000))                                              :integer          default(0)
#  mask(Hashcat mask (e.g. ?a?a?a?a?a?a?a?a))                                                          :string           default("")
#  name(Attack name)                                                                                   :string           default(""), not null
#  optimized(Is the attack optimized?)                                                                 :boolean          default(FALSE), not null
#  priority(The priority of the attack, higher numbers are higher priority.)                           :integer          default(0), not null
#  right_rule(Right rule)                                                                              :string           default("")
#  slow_candidate_generators(Are slow candidate generators enabled?)                                   :boolean          default(FALSE), not null
#  start_time(The time the attack started.)                                                            :datetime
#  state                                                                                               :string           indexed => [campaign_id], indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           not null, indexed, indexed => [state]
#  creator_id(The user who created this attack)                                                        :bigint           indexed
#  mask_list_id(The mask list used for the attack.)                                                    :bigint           indexed
#  rule_list_id(The rule list used for the attack.)                                                    :bigint           indexed
#  word_list_id(The word list used for the attack.)                                                    :bigint           indexed
#
# Indexes
#
#  index_attacks_campaign_id               (campaign_id)
#  index_attacks_on_attack_mode            (attack_mode)
#  index_attacks_on_campaign_id_and_state  (campaign_id,state)
#  index_attacks_on_complexity_value       (complexity_value)
#  index_attacks_on_creator_id             (creator_id)
#  index_attacks_on_deleted_at             (deleted_at)
#  index_attacks_on_mask_list_id           (mask_list_id)
#  index_attacks_on_rule_list_id           (rule_list_id)
#  index_attacks_on_state                  (state)
#  index_attacks_on_word_list_id           (word_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (mask_list_id => mask_lists.id) ON DELETE => cascade
#  fk_rails_...  (rule_list_id => rule_lists.id) ON DELETE => cascade
#  fk_rails_...  (word_list_id => word_lists.id) ON DELETE => cascade
#
class Attack < ApplicationRecord
  acts_as_paranoid # Soft deletes the attack

  ##
  # Associations
  #
  belongs_to :campaign, counter_cache: true
  has_many :tasks, dependent: :destroy, autosave: true
  has_many :hash_items, dependent: :nullify
  has_one :hash_list, through: :campaign
  belongs_to :rule_list, optional: true
  belongs_to :mask_list, optional: true
  belongs_to :word_list, optional: true
  belongs_to :creator, class_name: "User", optional: true

  # Validations
  validates :attack_mode, presence: true,
                          inclusion: { in: %w[dictionary mask hybrid_dictionary hybrid_mask] }
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :increment_mode, inclusion: { in: [true, false] }
  validates :increment_minimum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :increment_maximum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :markov_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :slow_candidate_generators, inclusion: { in: [true, false] }
  validates :optimized, inclusion: { in: [true, false] }
  validates :disable_markov, inclusion: { in: [true, false] }
  validates :classic_markov, inclusion: { in: [true, false] }
  validates :workload_profile, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 4 }
  validates :mask, length: { maximum: 512 }, allow_nil: true

  ##
  # Conditional Associations
  #
  with_options if: -> { dictionary? } do
    validates :word_list, presence: true
    validates_associated :word_list
    validates :mask, absence: true
    validates :mask_list, absence: true, allow_blank: true
    validates :increment_mode, comparison: { equal_to: false }, allow_blank: true
  end

  with_options if: -> { mask? } do
    validate :validate_mask_or_mask_list
    validates :word_list, absence: true
    validates :increment_minimum, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true, if: -> { increment_mode? }
    validates :increment_minimum, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true, if: -> { increment_mode? }
    validates :rule_list, absence: true, allow_blank: true
    validates :markov_threshold, comparison: { equal_to: 0 }, allow_blank: true
  end

  with_options if: -> { hybrid_dictionary? } do
    validates :word_list, presence: true
    validates_associated :word_list
    validates :mask, presence: true
    validates :mask_list, absence: true, allow_blank: true
    validates :increment_mode, comparison: { equal_to: false }, allow_blank: true
    validates :rule_list, absence: true, allow_blank: true
    validates :markov_threshold, comparison: { equal_to: 0 }, allow_blank: true
  end

  with_options if: -> { hybrid_mask? } do
    validates :word_list, presence: true
    validates_associated :word_list
    validates :mask, presence: true
    validates :mask_list, absence: true
    validates :increment_mode, comparison: { equal_to: false }, allow_blank: true
    validates :markov_threshold, comparison: { equal_to: 0 }, allow_blank: true
  end

  # Enumerations
  enum :attack_mode, { dictionary: 0, mask: 3, hybrid_dictionary: 6, hybrid_mask: 7 }

  ##
  # Scopes
  #
  scope :by_complexity, -> { order(:complexity_value, :created_at) }
  scope :pending, -> { with_state(:pending) }
  scope :incomplete, -> { without_states(:completed, :exhausted, :running, :paused) }
  scope :active, -> { with_states(:running, :pending) }

  # Concerns
  include SafeBroadcasting
  include AttackHashcatParameters
  include AttackComplexityCalculation
  include AttackStateMachine
  include AttackProgress

  ##
  # Delegations
  #
  delegate :uncracked_count, to: :campaign, allow_nil: true # Delegates the uncracked_count method to the campaign
  delegate :hash_mode, to: :hash_list # Delegates the hash_mode method to the hash list
  alias_method :hash_type, :hash_mode # Alias for hash_mode

  # Callbacks
  after_commit :broadcast_attack_progress_update, on: [:update]

  def to_full_label
    "#{campaign.name} - #{to_label}"
  end

  # Returns a string representation of the attack instance, combining the name and attack mode.
  #
  # @return [String] a formatted string in the form of "name (attack_mode)"
  def to_label
    "#{name} (#{attack_mode})"
  end

  # Returns a string representation of the attack instance, combining the name, attack mode, and complexity.
  #
  # @return [String] a formatted string in the form of "name (attack_mode) - complexity"
  def to_label_with_complexity
    "#{to_label} #{complexity_as_words}"
  end

  # Returns the latest agent error for this attack via its tasks.
  #
  # @return [AgentError, nil] the most recent agent error, or nil if none exist.
  def latest_agent_error
    AgentError.joins(:task).where(tasks: { attack_id: id }).order(created_at: :desc).first
  end

  def broadcast_attack_progress_update
    Rails.logger.info("[BroadcastUpdate] Attack #{id} - Broadcasting progress update to campaign #{campaign_id}")
    broadcast_replace_to(
      campaign,
      target: "attack-progress-#{id}",
      partial: "campaigns/attack_progress",
      locals: {
        attack: self,
        campaign: campaign,
        failed_attack_error_map: build_failed_attack_error_map
      }
    )

    # Also broadcast the campaign's ETA summary update
    campaign.broadcast_eta_update
  end

  # Builds a hash mapping this attack's ID to its latest error, if failed.
  #
  # @return [Hash] a hash with attack ID as key and error as value, or empty if not failed.
  def build_failed_attack_error_map
    return {} unless state == "failed"

    error = latest_agent_error
    error ? { id => error } : {}
  end

  private

  # Validates the presence of either `mask` or `mask_list`.
  # If both `mask` and `mask_list` are blank, adds errors to both attributes.
  #
  # @return [void]
  def validate_mask_or_mask_list
    return unless mask.blank? && mask_list.blank?
    errors.add(:mask, "must be present if mask lists are not present")
    errors.add(:mask_list, "must be present if mask is not present")
  end
end
