# == Schema Information
#
# Table name: cracker_operating_systems
#
#  id                 :bigint           not null, primary key
#  executable_command :text
#  operating_system   :integer          default("unknown"), indexed
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  cracker_id         :bigint           not null, indexed
#
# Indexes
#
#  index_cracker_operating_systems_on_cracker_id        (cracker_id)
#  index_cracker_operating_systems_on_operating_system  (operating_system)
#
# Foreign Keys
#
#  fk_rails_...  (cracker_id => crackers.id)
#
FactoryBot.define do
  factory :cracker_operating_system do
    operating_system { 1 }
    executable_command { "MyText" }
  end
end
