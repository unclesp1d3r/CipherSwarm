# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The HashcatGuess class represents a record of guesses made during a brute-force attack
# in the context of a hashcat session. It belongs to a HashcatStatus and contains details
# about base and modified guess values, their counts, offsets, completion percentages,
# and the mode used for the guessing process.
#
# == Relationships
# * Belongs to a hashcat_status which provides contextual information about the overall hashcat session
#
# == Validations
# * Validates the presence of all attributes to ensure complete data integrity
# * Enforces numericality for applicable attributes:
#   - guess_base_count, guess_base_offset, and guess_mode must be integers
#   - guess_base_percentage must be a numeric value
#   - guess_mod_count and guess_mod_offset must be integers
#   - guess_mod_percentage must be a numeric value
#
# == Aliases
# * `guess_base_percentage` is aliased as `guess_base_percent` for readability
# * `guess_mod_percentage` is aliased as `guess_mod_percent` for readability
#
# This class is derived from ApplicationRecord, enabling it to leverage Active Record's
# features for database interaction, validations, and associations.
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
class HashcatGuess < ApplicationRecord
  belongs_to :hashcat_status
  validates :guess_base, presence: true
  validates :guess_base_count, presence: true, numericality: { only_integer: true }
  validates :guess_base_offset, presence: true, numericality: { only_integer: true }
  validates :guess_base_percentage, presence: true, numericality: true
  validates :guess_mod_count, presence: true, numericality: { only_integer: true }
  validates :guess_mod_offset, presence: true, numericality: { only_integer: true }
  validates :guess_mod_percentage, presence: true, numericality: true
  validates :guess_mode, presence: true, numericality: { only_integer: true }

  # Aliases to make the attribute names more readable.
  alias_attribute :guess_base_percent, :guess_base_percentage
  alias_attribute :guess_mod_percent, :guess_mod_percentage
end
