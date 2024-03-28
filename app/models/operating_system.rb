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
#  index_operating_systems_on_name  (name) UNIQUE
#
class OperatingSystem < ApplicationRecord
  has_and_belongs_to_many :cracker_binaries # The cracker binaries that support this operating system.

  validates :name, presence: true
  validates :cracker_command, presence: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :name, length: { maximum: 255 }
  validates :cracker_command, length: { maximum: 255 }
  validates :cracker_command, format: { without: /\s/ }

  # Returns a string representation of the operating system.
  def to_s
    name
  end
end
