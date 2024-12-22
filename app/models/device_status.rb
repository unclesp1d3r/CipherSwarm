# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents the status of a specific device associated with a Hashcat task.
#
# == Associations
# - Belongs to a HashcatStatus, which represents the state of a Hashcat process.
#
# == Validations
# - Ensures the presence of the device name.
# - Ensures the presence and numericality (integer) of the device ID.
# - Ensures the presence of the device type.
# - Ensures the presence and numericality (integer) of the speed.
# - Ensures the presence and numericality (integer) of the temperature.
# - Ensures the presence and numericality (integer) of the utilization.
class DeviceStatus < ApplicationRecord
  belongs_to :hashcat_status
  validates :device_name, presence: true
  validates :device_type, presence: true
  validates :device_id, presence: true, numericality: { only_integer: true }
  validates :speed, presence: true, numericality: { only_integer: true }
  validates :temperature, presence: true, numericality: { only_integer: true }
  validates :utilization, presence: true, numericality: { only_integer: true }
end
