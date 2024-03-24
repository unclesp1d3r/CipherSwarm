# == Schema Information
#
# Table name: operations
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
#  right_rule(Right rule)                                                                              :string           default("")
#  slow_candidate_generators(Are slow candidate generators enabled?)                                   :boolean          default(FALSE), not null
#  status(Operation status)                                                                            :integer          default(0), not null, indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           indexed
#  cracker_id                                                                                          :bigint           indexed
#
# Indexes
#
#  index_operations_on_attack_mode  (attack_mode)
#  index_operations_on_campaign_id  (campaign_id)
#  index_operations_on_cracker_id   (cracker_id)
#  index_operations_on_status       (status)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (cracker_id => crackers.id)
#
class Operation < ApplicationRecord
  # Base model for templates and attacks
  has_and_belongs_to_many :word_lists
  has_and_belongs_to_many :rule_lists
  belongs_to :cracker

  validates :attack_mode, presence: true
  validates :increment_maximum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :increment_minimum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :markov_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :workload_profile, presence: true, inclusion: { in: 1..4 }

  enum attack_mode: {
    dictionary: 0,
    combination: 1,
    bruteforce: 3,
    hybrid_dict: 6,
    hybrid_mask: 7
  }

  # Generates the command line parameters for running hashcat.
  #
  # Returns:
  # - A string containing the command line parameters for hashcat.
  #
  def hashcat_parameters
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
