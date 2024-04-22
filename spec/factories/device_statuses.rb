# frozen_string_literal: true

# == Schema Information
#
# Table name: device_statuses
#
#  id                                                        :bigint           not null, primary key
#  device_name(Device Name)                                  :string
#  device_type(Device Type)                                  :string
#  speed(Speed )                                             :integer
#  temperature(Temperature in Celsius (-1 if not available)) :integer
#  utilization(Utilization Percentage)                       :integer
#  created_at                                                :datetime         not null
#  updated_at                                                :datetime         not null
#  device_id(Device ID)                                      :integer
#  hashcat_status_id                                         :bigint           not null, indexed
#
# Indexes
#
#  index_device_statuses_on_hashcat_status_id  (hashcat_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (hashcat_status_id => hashcat_statuses.id)
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
