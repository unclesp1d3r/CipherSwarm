# == Schema Information
#
# Table name: crackers
#
#  id                        :bigint           not null, primary key
#  name(Name of the cracker) :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class Cracker < ApplicationRecord
  validates :name, presence: true
  has_many :cracker_binaries, dependent: :destroy
end
