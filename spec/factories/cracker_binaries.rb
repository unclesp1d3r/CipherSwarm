# == Schema Information
#
# Table name: cracker_binaries
#
#  id                                                                :bigint           not null, primary key
#  active(Is the cracker binary active?)                             :boolean          default(TRUE)
#  major_version(The major version of the cracker binary.)           :integer
#  minor_version(The minor version of the cracker binary.)           :integer
#  patch_version(The patch version of the cracker binary.)           :integer
#  prerelease_version(The prerelease version of the cracker binary.) :string           default("")
#  version(Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1)   :string           not null, indexed => [cracker_id]
#  created_at                                                        :datetime         not null
#  updated_at                                                        :datetime         not null
#  cracker_id                                                        :bigint           not null, indexed, indexed => [version]
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
    active { true }
    version { Faker::App.semantic_version }
    cracker
    operating_systems do
      [ create(:operating_system, name: "Darwin"), create(:operating_system, name: "Windows") ]
    end

    after(:build) do |cracker_binary|
      cracker_binary.archive_file.attach(
        io: Rails.root.join("spec/fixtures/cracker_binaries/hashcat.7z").open,
        filename: "hashcat-6.0.0.tar.gz", content_type: "application/x-7z-compressed")
    end
  end
end
