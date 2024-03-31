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
require 'rails_helper'

RSpec.describe DeviceStatus do
  describe 'associations' do
    it { is_expected.to belong_to(:hashcat_status) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:device_name) }
    it { is_expected.to validate_presence_of(:device_type) }
    it { is_expected.to validate_presence_of(:speed) }
    it { is_expected.to validate_presence_of(:temperature) }
    it { is_expected.to validate_presence_of(:utilization) }
    it { is_expected.to validate_presence_of(:device_id) }
  end

  describe 'factory' do
    it 'is expected to have valid DeviceStatus factory' do
      expect(create(:device_status)).to be_valid
    end
  end
end
