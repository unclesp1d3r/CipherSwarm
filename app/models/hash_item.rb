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
# == Schema Information
#
# Table name: hash_items
#
#  id                                                    :bigint           not null, primary key
#  cracked(Is the hash cracked?)                         :boolean          default(FALSE), not null
#  cracked_time(Time when the hash was cracked)          :datetime
#  hash_value(Hash value)                                :text             not null
#  metadata(Optional metadata fields for the hash item.) :jsonb            not null
#  plain_text(Plaintext value of the hash)               :string
#  salt(Salt of the hash)                                :text
#  created_at                                            :datetime         not null
#  updated_at                                            :datetime         not null
#  attack_id(The attack that cracked this hash)          :bigint           indexed
#  hash_list_id                                          :bigint           not null, indexed
#
# Indexes
#
#  index_hash_items_on_attack_id     (attack_id)
#  index_hash_items_on_hash_list_id  (hash_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (attack_id => attacks.id)
#  fk_rails_...  (hash_list_id => hash_lists.id)
#
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
