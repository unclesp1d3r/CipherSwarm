# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
FactoryBot.define do
  factory :hash_item do
    cracked { false }
    hash_value { Faker::Crypto.md5 }
    hash_list
  end
end
