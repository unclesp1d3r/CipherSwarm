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

RSpec.describe Cracker, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(50) }
  it { is_expected.to have_many(:cracker_binaries) }
end
