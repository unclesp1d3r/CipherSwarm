# frozen_string_literal: true

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
#  fk_rails_...  (hashcat_status_id => hashcat_statuses.id)
#
class DeviceStatus < ApplicationRecord
  belongs_to :hashcat_status
  validates :device_name, presence: true
  validates :device_type, presence: true
  validates :device_id, presence: true, numericality: { only_integer: true }
  validates :speed, presence: true, numericality: { only_integer: true }
  validates :temperature, presence: true, numericality: { only_integer: true }
  validates :utilization, presence: true, numericality: { only_integer: true }
end
