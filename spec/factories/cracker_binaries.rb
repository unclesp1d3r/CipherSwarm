# == Schema Information
#
# Table name: cracker_binaries
#
#  id                                                              :bigint           not null, primary key
#  active(Is the cracker binary active?)                           :boolean          default(TRUE)
#  version(Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1) :string           not null, indexed => [cracker_id]
#  created_at                                                      :datetime         not null
#  updated_at                                                      :datetime         not null
#  cracker_id                                                      :bigint           not null, indexed, indexed => [version]
#
# Indexes
#
#  index_cracker_binaries_on_cracker_id              (cracker_id)
#  index_cracker_binaries_on_version_and_cracker_id  (version,cracker_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cracker_id => crackers.id)
#
FactoryBot.define do
  factory :cracker_binary do
    version { "6.2.6" }
    active { true }
    association :cracker, factory: :hashcat
    association :operating_systems, factory: [ :windows, :darwin ]
  end
end
