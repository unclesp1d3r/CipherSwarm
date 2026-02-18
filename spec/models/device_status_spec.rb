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
require "rails_helper"

RSpec.describe DeviceStatus do
  describe "associations" do
    it { is_expected.to belong_to(:hashcat_status) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:device_name) }
    it { is_expected.to validate_presence_of(:device_type) }
    it { is_expected.to validate_presence_of(:speed) }
    it { is_expected.to validate_presence_of(:temperature) }
    it { is_expected.to validate_presence_of(:utilization) }
    it { is_expected.to validate_presence_of(:device_id) }
  end

  describe "cascade deletion" do
    it "is deleted when its parent hashcat_status is deleted" do
      device_status = create(:device_status)
      hashcat_status = device_status.hashcat_status

      hashcat_status.delete

      expect(described_class.exists?(device_status.id)).to be false
    end
  end

  describe "factory" do
    it "is expected to have valid DeviceStatus factory" do
      expect(create(:device_status)).to be_valid
    end
  end
end
