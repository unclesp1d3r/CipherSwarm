# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hash_items
#
#  id                                                    :bigint           not null, primary key
#  cracked(Is the hash cracked?)                         :boolean          default(FALSE), not null, indexed => [hash_value]
#  cracked_time(Time when the hash was cracked)          :datetime         indexed
#  hash_value(Hash value)                                :text             not null, indexed => [cracked], indexed => [hash_list_id]
#  metadata(Optional metadata fields for the hash item.) :jsonb            not null
#  plain_text(Plaintext value of the hash)               :string
#  salt(Salt of the hash)                                :text
#  created_at                                            :datetime         not null
#  updated_at                                            :datetime         not null
#  attack_id(The attack that cracked this hash)          :bigint           indexed
#  hash_list_id                                          :bigint           not null, indexed, indexed => [hash_value]
#
# Indexes
#
#  index_hash_items_on_attack_id                    (attack_id)
#  index_hash_items_on_cracked_time                 (cracked_time)
#  index_hash_items_on_hash_list_id                 (hash_list_id)
#  index_hash_items_on_hash_value_and_cracked       (hash_value,cracked)
#  index_hash_items_on_hash_value_and_hash_list_id  (hash_value,hash_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (attack_id => attacks.id) ON DELETE => nullify
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :hash_item do
    cracked { false }
    hash_value { Faker::Crypto.md5 }
    hash_list

    trait :cracked_recently do
      cracked { true }
      cracked_time { 1.hour.ago }
      plain_text { "password123" }
    end

    trait :cracked_old do
      cracked { true }
      cracked_time { 2.days.ago }
      plain_text { "oldpassword" }
    end
  end
end
