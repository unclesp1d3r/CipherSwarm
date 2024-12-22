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
