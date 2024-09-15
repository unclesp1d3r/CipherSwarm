# frozen_string_literal: true

# The HashcatGuess model represents a guess made by the Hashcat tool.
# It belongs to a HashcatStatus and includes various attributes related to the guess.
#
# This is generally derived from the hashcat output and is used to track the progress of the cracking process.
#
# Attributes:
# - guess_base: The base guess string.
# - guess_base_count: The count of base guesses.
# - guess_base_offset: The offset of the base guess.
# - guess_base_percentage: The percentage of the base guess.
# - guess_mod_count: The count of modified guesses.
# - guess_mod_offset: The offset of the modified guess.
# - guess_mod_percentage: The percentage of the modified guess.
# - guess_mode: The mode of the guess.
#
# Validations:
# - guess_base: Must be present.
# - guess_base_count: Must be present and an integer.
# - guess_base_offset: Must be present and an integer.
# - guess_base_percentage: Must be present and a number.
# - guess_mod_count: Must be present and an integer.
# - guess_mod_offset: Must be present and an integer.
# - guess_mod_percentage: Must be present and a number.
# - guess_mode: Must be present and an integer.
#
# Methods:
# - guess_base_percent: Getter for guess_base_percentage.
# - guess_base_percent=(value): Setter for guess_base_percentage.
# - guess_mod_percent: Getter for guess_mod_percentage.
# - guess_mod_percent=(value): Setter for guess_mod_percentage.
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
