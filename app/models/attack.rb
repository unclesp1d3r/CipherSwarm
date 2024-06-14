# frozen_string_literal: true

# == Schema Information
#
# Table name: attacks
#
#  id                                                                                                  :bigint           not null, primary key
#  attack_mode(Hashcat attack mode)                                                                    :integer          default("dictionary"), not null, indexed
#  classic_markov(Is classic Markov chain enabled?)                                                    :boolean          default(FALSE), not null
#  custom_charset_1(Custom charset 1)                                                                  :string           default("")
#  custom_charset_2(Custom charset 2)                                                                  :string           default("")
#  custom_charset_3(Custom charset 3)                                                                  :string           default("")
#  custom_charset_4(Custom charset 4)                                                                  :string           default("")
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
#  position(The position of the attack in the campaign.)                                               :integer          default(0), not null, indexed => [campaign_id]
#  priority(The priority of the attack, higher numbers are higher priority.)                           :integer          default(0), not null
#  right_rule(Right rule)                                                                              :string           default("")
#  slow_candidate_generators(Are slow candidate generators enabled?)                                   :boolean          default(FALSE), not null
#  start_time(The time the attack started.)                                                            :datetime
#  state                                                                                               :string           indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           not null, indexed => [position]
#
# Indexes
#
#  index_attacks_on_attack_mode               (attack_mode)
#  index_attacks_on_campaign_id_and_position  (campaign_id,position) UNIQUE
#  index_attacks_on_state                     (state)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
class Attack < ApplicationRecord
  belongs_to :campaign, touch: true, counter_cache: true
  positioned on: :campaign

  has_many :tasks, dependent: :destroy
  has_one :hash_list, through: :campaign
  has_and_belongs_to_many :word_lists
  has_and_belongs_to_many :rule_lists

  default_scope { order(:position) } # We want the highest priority attack first

  validates :attack_mode, presence: true,
                          inclusion: { in: %w[dictionary mask combinator hybrid_dictionary hybrid_mask] }
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

  with_options if: -> { attack_mode == :dictionary } do
    validates :word_lists, presence: true, length: { is: 1 }
    validates_associated :word_lists
    validates :mask, absence: true
    validates :rule_lists, absence: true
    validates :increment_mode, comparison: { equal_to: false }
  end

  with_options if: -> { attack_mode == :combinator } do
    validates :word_lists, length: { is: 2 }
    validates_associated :word_lists
    validates :rule_lists, absence: true
    validates :increment_mode, comparison: { equal_to: false }
    validates :mask, absence: true
  end

  with_options if: -> { attack_mode == :mask } do
    validates :mask, presence: true
    validates :word_lists, absence: true
    validates :increment_mode, comparison: { equal_to: false }
    validates :rule_lists, absence: true
    validates :markov_threshold, absence: true
  end

  with_options if: -> { attack_mode == :hybrid_dictionary } do
    validates :word_lists, length: { is: 1 }
    validates_associated :word_lists
    validates :mask, presence: true
    validates :increment_mode, comparison: { equal_to: false }
    validates :rule_lists, absence: true
    validates :markov_threshold, absence: true
  end

  with_options if: -> { attack_mode == :hybrid_mask } do
    validates :word_lists, length: { is: 1 }
    validates_associated :word_lists
    validates :mask, presence: true
    validates :increment_mode, comparison: { equal_to: false }
    validates :markov_threshold, absence: true
  end

  enum attack_mode: { dictionary: 0, combinator: 1, mask: 3, hybrid_dictionary: 6, hybrid_mask: 7 }

  scope :pending, -> { with_state(:pending) }
  scope :incomplete, -> { without_states(:completed, :paused, :exhausted) }

  broadcasts_refreshes unless Rails.env.test?

  state_machine :state, initial: :pending do
    event :accept do
      transition all - %i[completed exhausted] => :running
    end

    event :run do
      transition pending: :running
    end

    event :complete do
      transition running: :completed if ->(attack) { attack.tasks.all?(&:completed?) }
      transition pending: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
      transition all - [:running] => same
    end

    event :pause do
      transition running: :paused
    end

    event :error do
      transition running: :failed
      transition any => same
    end

    event :exhaust do
      transition running: :completed if ->(attack) { attack.tasks.all?(&:exhausted?) }
      transition running: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
      transition all - [:running] => same
    end

    event :cancel do
      transition %i[pending running] => :failed
    end

    event :reset do
      transition %i[failed completed exhausted] => :pending
    end

    event :abandon do
      transition running: :pending if ->(attack) { attack.tasks.without_status(:running).any? }
      transition any => same
    end

    after_transition on: :running do |attack|
      attack.update(start_time: Time.zone.now)
    end

    after_transition on: :complete do |attack|
      attack.update(end_time: Time.zone.now)
    end

    before_transition on: :pause do |attack|
      attack.tasks.each(&:pause!)
    end

    before_transition on: :complete do |attack|
      attack.tasks.each(&:complete!) if attack.hash_list.uncracked_count.zero?
    end

    state :completed do
      validates :tasks, presence: true
    end
    state :running do
      validates :tasks, presence: true
    end
    state :paused
    state :failed
    state :exhausted
    state :pending
  end

  def estimated_finish_time
    tasks.with_state(:running).first&.estimated_finish_time
  end

  def hash_type
    campaign.hash_list.hash_mode
  end

  # Generates the command line parameters for running hashcat.
  #
  # Returns:
  # - A string containing the command line parameters for hashcat.
  #
  def hashcat_parameters
    parameters = []

    # Add attack mode parameter
    parameters << "-a #{Attack.attack_modes[attack_mode]}"

    # Add markov threshold parameter if classic markov is enabled
    parameters << "--markov-threshold=#{markov_threshold}" if classic_markov

    # Add optimized parameter if enabled
    parameters << "-O" if optimized

    # Add increment mode parameter if enabled
    parameters << "--increment" if increment_mode

    # Add increment minimum and maximum parameters if increment mode is enabled
    parameters << "--increment-min #{increment_minimum}" if increment_mode
    parameters << "--increment-max #{increment_maximum}" if increment_mode

    # Add markov disable parameter if markov is disabled
    parameters << "--markov-disable" if disable_markov

    # Add markov classic parameter if classic markov is enabled
    parameters << "--markov-classic" if classic_markov

    # Add markov threshold parameter if present
    parameters << "-t #{markov_threshold}" if markov_threshold.present?

    # Add slow candidate generators parameter if enabled
    parameters << "-S" if slow_candidate_generators

    # Add custom charset 1 parameter if present
    parameters << "-1 #{custom_charset_1}" if custom_charset_1.present?

    # Add custom charset 2 parameter if present
    parameters << "-2 #{custom_charset_2}" if custom_charset_2.present?

    # Add custom charset 3 parameter if present
    parameters << "-3 #{custom_charset_3}" if custom_charset_3.present?

    # Add custom charset 4 parameter if present
    parameters << "-4 #{custom_charset_4}" if custom_charset_4.present?

    # Add workload profile parameter
    parameters << "-w #{workload_profile}"

    # Add word lists parameters
    word_lists.each do |word_list|
      parameters << "#{word_list.file.filename}"
    end

    # Add rule lists parameters
    rule_lists.each do |rule_list|
      parameters << "-r #{rule_list.file.filename}"
    end

    parameters.join(" ")
  end

  # Calculates the percentage of completion for the attack.
  #
  # This method retrieves the first running task associated with the attack
  # and returns its progress percentage. If there are no running tasks,
  # it returns 0.
  #
  # @return [Float] The percentage of completion for the attack.
  def percentage_complete
    running_task = tasks.with_state(:running).first
    return 0 if running_task.nil?

    running_task.progress_percentage
  end

  def run_time
    if start_time.nil? || end_time.nil?
      return nil
    end
    end_time - start_time
  end
end
