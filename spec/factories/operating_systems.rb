# frozen_string_literal: true

# == Schema Information
#
# Table name: operating_systems
#
#  id                                                     :bigint           not null, primary key
#  cracker_command(Command to run the cracker on this OS) :string           not null
#  name(Name of the operating system)                     :string           not null, indexed
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#
# Indexes
#
#  index_operating_systems_on_name  (name) UNIQUE
#
FactoryBot.define do
  factory :operating_system do
    name { "linux" }
    cracker_command { "hashcat" }
  end
end
