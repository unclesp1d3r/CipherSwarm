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
#  campaign_id                                                                                         :bigint           indexed, indexed => [position]
#
# Indexes
#
#  index_attacks_on_attack_mode               (attack_mode)
#  index_attacks_on_campaign_id               (campaign_id)
#  index_attacks_on_campaign_id_and_position  (campaign_id,position) UNIQUE
#  index_attacks_on_state                     (state)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
require "rails_helper"

RSpec.describe Attack do
  context "with associations" do
    it { is_expected.to belong_to(:campaign) }
    it { is_expected.to have_many(:tasks).dependent(:destroy) }
    it { is_expected.to have_and_belong_to_many(:word_lists) }
    it { is_expected.to have_and_belong_to_many(:rule_lists) }
  end

  context "with validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:attack_mode) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(65_535) }
    it { is_expected.to validate_presence_of(:workload_profile) }
    it { is_expected.to validate_numericality_of(:workload_profile).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(4) }
    it { is_expected.to validate_length_of(:mask).is_at_most(512).allow_nil }
    it { is_expected.to validate_numericality_of(:increment_minimum).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:increment_maximum).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:markov_threshold).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "dictionary attack mode" do
    # Dictionary Attack specific validations
    # Dictionary attacks require at least one word list
    subject(:dictionary_attack) { build(:dictionary_attack) }

    it { expect(dictionary_attack).to be_valid }
    it { expect(dictionary_attack.attack_mode).to eq("dictionary") }
    it { expect(dictionary_attack.increment_mode).to be_falsey }
    it { expect(dictionary_attack.increment_minimum).to eq(0) }
    it { expect(dictionary_attack.increment_maximum).to eq(0) }
    # it { is_expected.to validate_absence_of(:mask) } # Can't get this to work
  end

  describe "combinator attack mode" do
    # Combinator Attack specific validations
    # Requires 2 word lists
    # Does not allow increment mode
    # Does not allow mask
    # Allows left and right rules
    # Does not allow rule lists
    subject(:combinator_attack) { create(:combination_attack) }

    it { expect(combinator_attack).to be_valid }
    it { expect(combinator_attack.attack_mode).to eq("combinator") }
    it { expect(combinator_attack.word_lists.count).to eq(2) }
    # it { expect(combinator_attack).to validate_absence_of(:mask) } # Can't get this to work
  end

  describe "mask attack mode" do
    # Mask Attack specific validations
    # Require a mask
    # Does not allow word lists
    # Does allow increment mode
    # Does not allow rule lists
    subject(:mask_attack) { build(:mask_attack) }

    it { expect(mask_attack).to be_valid }
  end

  describe "increment attack mode" do
    # Increment attacks require increment mode
    subject(:increment_attack) { build(:increment_attack) }

    it { expect(increment_attack).to be_valid }
  end

  describe "hybrid dictionary attack mode" do
    # Hybrid Dictionary Attack specific validations
    # Requires a mask
    # Requires a word list
    subject(:hybrid_dictionary_attack) { build(:hybrid_dictionary_attack) }

    it { expect(hybrid_dictionary_attack).to be_valid }
  end

  describe "hybrid mask attack mode" do
    # Hybrid Mask Attack specific validations
    # Requires a mask
    # Requires a word list
    subject(:hybrid_mask_attack) { build(:hybrid_mask_attack) }

    it { expect(hybrid_mask_attack).to be_valid }
  end

  context "with a valid factory" do
    subject(:attack) { build(:dictionary_attack) }

    it { expect(attack).to be_valid }
  end
end
