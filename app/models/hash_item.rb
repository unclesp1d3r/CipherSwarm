# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The HashItem class is an ActiveRecord model representing an individual hash entry.
#
# It is associated with a HashList, representing a collection of hash items,
# and optionally with an Attack, which may have been used to crack the hash.
#
# == Validations:
# - `hash_value`: Must be present.
# - `salt`: Maximum length of 255 characters.
# - `plain_text`: Maximum length of 255 characters.
# - `metadata`: Maximum length of 255 characters.
#
# == Scopes:
# - `cracked`: Retrieves all hash items that have been successfully cracked.
# - `uncracked`: Retrieves all hash items that have not been cracked.
#
# == Associations:
# - `hash_list`: A required association linking the hash item to a HashList, with touch and counter cache enabled.
# - `attack`: An optional association linking the hash item to an Attack.
#
# == Instance Methods:
# - `to_s`: Provides a string representation of the hash item in the format of either
#   "hash_value:salt:plain_text" (if salt is present) or "hash_value:plain_text".
class HashItem < ApplicationRecord
  belongs_to :hash_list, touch: true, counter_cache: true
  belongs_to :attack, optional: true
  validates :hash_value, presence: true
  validates :hash_value, presence: true
  validates :salt, length: { maximum: 255 }
  validates :plain_text, length: { maximum: 255 }
  validates :metadata, length: { maximum: 255 }

  scope :cracked, -> { where(cracked: true) }
  scope :uncracked, -> { where(cracked: false) }

  # Returns a string representation of the hash item.
  # If the salt is present, the format will be "hash_value:salt:plain_text".
  # Otherwise, the format will be "hash_value:plain_text".
  #
  # @return [String] the string representation of the hash item.
  def to_s
    if salt.present?
      "#{hash_value}:#{salt}:#{plain_text}"
    else
      "#{hash_value}:#{plain_text}"
    end
  end
end
