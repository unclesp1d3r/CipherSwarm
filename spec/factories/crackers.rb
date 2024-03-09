# == Schema Information
#
# Table name: crackers
#
#  id                        :bigint           not null, primary key
#  name(Name of the cracker) :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
FactoryBot.define do
  factory :cracker do
    name { "MyString" }
    version { "MyString" }
    archive_file { nil }
    active { false }
  end
end
