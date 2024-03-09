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
FactoryBot.define do
  factory :operating_system do
    name { "MyString" }
    cracker_command { "MyString" }
    cracker { nil }
  end
end
