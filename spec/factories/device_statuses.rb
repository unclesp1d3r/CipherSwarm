# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: device_statuses
#
#  id                                                        :bigint           not null, primary key
#  device_name(Device Name)                                  :string           not null
#  device_type(Device Type)                                  :string           not null
#  speed(Speed )                                             :bigint           not null
#  temperature(Temperature in Celsius (-1 if not available)) :integer          not null
#  utilization(Utilization Percentage)                       :integer          not null
#  created_at                                                :datetime         not null
#  updated_at                                                :datetime         not null
#  device_id(Device ID)                                      :integer          not null
#  hashcat_status_id                                         :bigint           not null, indexed
#
# Indexes
#
#  index_device_statuses_on_hashcat_status_id  (hashcat_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (hashcat_status_id => hashcat_statuses.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :device_status do
    device_id { Faker::Number.number(digits: 1) }
    device_name { "MyString" }
    device_type { "MyString" }
    speed { 100000 }
    utilization { 1 }
    temperature { 1 }
    hashcat_status
  end
end
