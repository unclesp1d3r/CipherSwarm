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
#  state                                                                                               :string           indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           indexed
#
# Indexes
#
#  index_attacks_on_attack_mode  (attack_mode)
#  index_attacks_on_campaign_id  (campaign_id)
#  index_attacks_on_state        (state)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
class Attack < ApplicationRecord # rubocop:disable Metrics/ClassLength
  belongs_to :campaign, touch: true
  has_many :tasks, dependent: :destroy
  has_one :hash_list, through: :campaign

  has_and_belongs_to_many :word_lists
  has_and_belongs_to_many :rule_lists

  validates :attack_mode, presence: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :workload_profile, presence: true
  validates :increment_mode, inclusion: { in: [ true, false ] }
  validates :increment_minimum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :increment_maximum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :markov_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :slow_candidate_generators, inclusion: { in: [ true, false ] }
  validates :optimized, inclusion: { in: [ true, false ] }
  validates :disable_markov, inclusion: { in: [ true, false ] }
  validates :classic_markov, inclusion: { in: [ true, false ] }
  validates :attack_mode, inclusion: { in: %w[dictionary mask hybrid combinator] }
  validates :workload_profile, inclusion: { in: 1..4 }
  validates :mask, length: { maximum: 512, allow_blank: true }

  enum attack_mode: { dictionary: 0, combinator: 1, mask: 3, hybrid_dictionary: 6, hybrid_mask: 7 }

  scope :pending, -> { with_state(:pending) }
  scope :incomplete, -> { without_states(:completed, :paused, :exhausted) }

  broadcasts_refreshes unless Rails.env.test?

  state_machine :state, initial: :pending do
    event :accept do
      transition all - [ :completed, :exhausted ] => :running
    end

    event :run do
      transition pending: :running
    end

    event :complete do
      transition running: :completed if ->(attack) { attack.tasks.all?(&:completed?) }
      transition pending: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
      transition all - [ :running ] => same
    end

    event :pause do
      transition running: :paused
    end

    event :error do
      transition running: :failed
    end

    event :exhaust do
      transition running: :completed if ->(attack) { attack.tasks.all?(&:exhausted?) }
      transition running: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
      transition all - [ :running ] => same
    end

    event :cancel do
      transition [ :pending, :running ] => :failed
    end

    before_transition on: :pause do |attack|
      attack.tasks.each(&:pause!)
    end

    before_transition on: :complete do |attack|
      if attack.hash_list.uncracked_count == 0
        attack.tasks.each(&:complete!)
      end
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

  def hash_type
    campaign.hash_list.hash_mode
  end

  def estimated_finish_time
    tasks.with_state(:running).first&.estimated_finish_time
  end

  def percentage_complete
    running_task = tasks.with_state(:running).first
    return 0 if running_task.nil?
    running_task.progress_percentage
  end

  # Generates the command line parameters for running hashcat.
  #
  # Returns:
  # - A string containing the command line parameters for hashcat.
  #
  def hashcat_parameters # rubocop:disable Metrics/MethodLength
    parameters = []

    parameters << "-a #{Attack.attack_modes[attack_mode]}"
    parameters << "--markov-threshold=#{markov_threshold}" if classic_markov
    parameters << "-O" if optimized
    parameters << "--increment" if increment_mode
    parameters << "--increment-min #{increment_minimum}" if increment_mode
    parameters << "--increment-max #{increment_maximum}" if increment_mode
    parameters << "--markov-disable" if disable_markov
    parameters << "--markov-classic" if classic_markov
    parameters << "-t #{markov_threshold}" if markov_threshold.present?
    parameters << "-S" if slow_candidate_generators
    parameters << "-1 #{custom_charset_1}" if custom_charset_1.present?
    parameters << "-2 #{custom_charset_2}" if custom_charset_2.present?
    parameters << "-3 #{custom_charset_3}" if custom_charset_3.present?
    parameters << "-4 #{custom_charset_4}" if custom_charset_4.present?
    parameters << "-w #{workload_profile}"
    word_lists.each { |word_list|
      parameters << "#{word_list.file.filename}"
    }
    rule_lists.each { |rule_list|
      parameters << "-r #{rule_list.file.filename}"
    }

    parameters.join(" ")
  end
end
