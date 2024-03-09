# == Schema Information
#
# Table name: operating_systems
#
#  id                                                     :bigint           not null, primary key
#  cracker_command(Command to run the cracker on this OS) :string
#  name(Name of the operating system)                     :string           indexed
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#
# Indexes
#
#  index_operating_systems_on_name  (name)
#
class OperatingSystem < ApplicationRecord
  has_and_belongs_to_many :crackers

  validates :name, presence: true
  validates :cracker_command, presence: true

  # Returns a string representation of the operating system.
  def to_s
    name
  end
end
