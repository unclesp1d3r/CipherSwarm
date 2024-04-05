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
require 'rails_helper'

RSpec.describe Attack do
  let!(:attack) { build(:attack) }

  context 'with associations' do
    it { is_expected.to have_many(:tasks).dependent(:destroy) }
  end

  context 'with validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:attack_mode) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(65_535) }
    it { is_expected.to validate_presence_of(:workload_profile) }
    it { is_expected.to validate_length_of(:mask).is_at_most(512).allow_nil }
    it { is_expected.to validate_numericality_of(:increment_minimum).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:increment_maximum).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:markov_threshold).only_integer.is_greater_than_or_equal_to(0) }
  end

  context 'with a valid factory' do
    it { expect(attack).to be_valid }
  end
end
