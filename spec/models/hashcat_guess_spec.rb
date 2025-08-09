# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hashcat_guesses
#
#  id                                                                     :bigint           not null, primary key
#  guess_base(The base value used for the guess (for example, the mask))  :string           not null
#  guess_base_count(The number of times the base value was used)          :bigint           not null
#  guess_base_offset(The offset of the base value)                        :bigint           not null
#  guess_base_percentage(The percentage completion of the base value)     :decimal(, )      not null
#  guess_mod(The modifier used for the guess (for example, the wordlist)) :string
#  guess_mod_count(The number of times the modifier was used)             :bigint           not null
#  guess_mod_offset(The offset of the modifier)                           :bigint           not null
#  guess_mod_percentage(The percentage completion of the modifier)        :decimal(, )      not null
#  guess_mode(The mode used for the guess)                                :integer          not null
#  created_at                                                             :datetime         not null
#  updated_at                                                             :datetime         not null
#  hashcat_status_id                                                      :bigint           not null, indexed, indexed
#
# Indexes
#
#  index_hashcat_guesses_hashcat_status_id     (hashcat_status_id) UNIQUE
#  index_hashcat_guesses_on_hashcat_status_id  (hashcat_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (hashcat_status_id => hashcat_statuses.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe HashcatGuess do
  describe "associations" do
    it { is_expected.to belong_to(:hashcat_status) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:guess_base) }
    it { is_expected.to validate_presence_of(:guess_base_count) }
    it { is_expected.to validate_presence_of(:guess_base_offset) }
    it { is_expected.to validate_presence_of(:guess_base_percentage) }
    it { is_expected.to validate_presence_of(:guess_mod_count) }
    it { is_expected.to validate_presence_of(:guess_mod_offset) }
    it { is_expected.to validate_presence_of(:guess_mod_percentage) }
    it { is_expected.to validate_presence_of(:guess_mode) }
  end

  describe "factory" do
    it "is valid" do
      expect(build(:hashcat_guess)).to be_valid
    end
  end
end
