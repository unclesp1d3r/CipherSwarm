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
FactoryBot.define do
  factory :cracker do
    name { "MyString" }
    version { "MyString" }
    archive_file { nil }
    active { false }
  end
end
