# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hash_types
#
#  id                                          :bigint           not null, primary key
#  built_in(Whether the hash type is built-in) :boolean          default(FALSE), not null
#  category(The category of the hash type)     :integer          default("raw_hash"), not null
#  enabled(Whether the hash type is enabled)   :boolean          default(TRUE), not null
#  hashcat_mode(The hashcat mode number)       :integer          not null, uniquely indexed
#  is_slow(Whether the hash type is slow)      :boolean          default(FALSE), not null
#  name(The name of the hash type)             :string           not null, uniquely indexed
#  created_at                                  :datetime         not null
#  updated_at                                  :datetime         not null
#
# Indexes
#
#  index_hash_types_on_hashcat_mode  (hashcat_mode) UNIQUE
#  index_hash_types_on_name          (name) UNIQUE
#
FactoryBot.define do
  factory :hash_type do
    hashcat_mode { Faker::Number.number(digits: 4) }
    name { Faker::Lorem.words(number: 5).join(' ') }
    category { 0 }
    enabled { true }
    built_in { false }
    is_slow { false }
    factory :md5 do
      hashcat_mode { 0 }
      name { "MD5" }
      category { 0 }
    end
  end
end
