# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: operating_systems
#
#  id                                                     :bigint           not null, primary key
#  cracker_command(Command to run the cracker on this OS) :string           not null
#  name(Name of the operating system)                     :string           not null, uniquely indexed
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#
# Indexes
#
#  index_operating_systems_on_name  (name) UNIQUE
#
FactoryBot.define do
  factory :operating_system do
    sequence(:name) do |n|
      base_names = %w[linux windows darwin freebsd openbsd netbsd solaris]
      idx = n - 1
      idx < base_names.length ? base_names[idx] : "#{base_names[idx % base_names.length]}-#{n}"
    end
    cracker_command { "hashcat" }
  end
end
