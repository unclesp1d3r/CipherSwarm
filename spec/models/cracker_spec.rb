# == Schema Information
#
# Table name: crackers
#
#  id                        :bigint           not null, primary key
#  name(Name of the cracker) :string           indexed
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_crackers_on_name  (name) UNIQUE
#
require 'rails_helper'

RSpec.describe Cracker do
  subject { build(:cracker) }

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(50) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:cracker_binaries) }
    it { is_expected.to have_many(:operating_systems).through(:cracker_binaries) }
  end

  describe 'factory' do
    it { is_expected.to be_valid }
  end

  describe 'database' do
    it { is_expected.to have_db_index(:name).unique(true) }
  end
end
