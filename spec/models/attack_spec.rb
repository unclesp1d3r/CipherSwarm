# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
#  state                                                                                               :string           indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           not null, indexed
#  mask_list_id(The mask list used for the attack.)                                                    :bigint           indexed
#  rule_list_id(The rule list used for the attack.)                                                    :bigint           indexed
#  word_list_id(The word list used for the attack.)                                                    :bigint           indexed
#
# Indexes
#
#  index_attacks_campaign_id          (campaign_id)
#  index_attacks_on_attack_mode       (attack_mode)
#  index_attacks_on_complexity_value  (complexity_value)
#  index_attacks_on_deleted_at        (deleted_at)
#  index_attacks_on_mask_list_id      (mask_list_id)
#  index_attacks_on_rule_list_id      (rule_list_id)
#  index_attacks_on_state             (state)
#  index_attacks_on_word_list_id      (word_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#  fk_rails_...  (mask_list_id => mask_lists.id) ON DELETE => cascade
#  fk_rails_...  (rule_list_id => rule_lists.id) ON DELETE => cascade
#  fk_rails_...  (word_list_id => word_lists.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Attack do
  context "with associations" do
    it { is_expected.to belong_to(:campaign) }
    it { is_expected.to have_many(:tasks).dependent(:destroy) }
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
    it { is_expected.to validate_presence_of(:word_list) }
    # it { is_expected.to validate_absence_of(:mask) } # Can't get this to work
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

  describe "mask attack mode with list" do
    subject(:mask_attack) { build(:mask_list_attack) }

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

  context "when deleted" do
    subject(:attack) { build(:dictionary_attack) }

    let!(:child_task) { create(:task, attack: attack) }

    it { expect(child_task).to be_valid }
    it { expect(attack.tasks.count).to eq(1) }
    it { expect { attack.destroy }.to change(Task, :count).by(-1) }
  end

  describe "SafeBroadcasting integration" do
    let(:attack) { create(:dictionary_attack) }

    it "includes SafeBroadcasting concern" do
      expect(described_class.included_modules).to include(SafeBroadcasting)
    end

    context "when broadcast fails" do
      it "logs BroadcastError without raising" do
        allow(Rails.logger).to receive(:error)
        expect { attack.send(:log_broadcast_error, StandardError.new("Connection refused")) }.not_to raise_error
      end

      it "includes attack ID in broadcast error log" do
        allow(Rails.logger).to receive(:error)
        attack.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/Record ID: #{attack.id}/).at_least(:once)
      end

      it "includes model name in broadcast error log" do
        # Note: Attack is the base class name, not DictionaryAttack (the STI subclass)
        allow(Rails.logger).to receive(:error)
        attack.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/\[BroadcastError\].*Model: Attack/).at_least(:once)
      end
    end
  end
end
