# frozen_string_literal: true

# == Schema Information
#
# Table name: hash_lists
#
#  id                                                                                                                        :bigint           not null, primary key
#  description(Description of the hash list)                                                                                 :text
#  hash_items_count                                                                                                          :integer          default(0)
#  metadata_fields_count(Number of metadata fields in the hash list file. Default is 0.)                                     :integer          default(0), not null
#  name(Name of the hash list)                                                                                               :string           not null, indexed
#  processed(Is the hash list processed into hash items?)                                                                    :boolean          default(FALSE)
#  salt(Does the hash list contain a salt?)                                                                                  :boolean          default(FALSE)
#  sensitive(Is the hash list sensitive?)                                                                                    :boolean          default(FALSE)
#  separator(Separator used in the hash list file to separate the hash from the password or other metadata. Default is ":".) :string(1)        default(":"), not null
#  created_at                                                                                                                :datetime         not null
#  updated_at                                                                                                                :datetime         not null
#  hash_type_id                                                                                                              :bigint           indexed
#  project_id(Project that the hash list belongs to)                                                                         :bigint           not null, indexed
#
# Indexes
#
#  index_hash_lists_on_hash_type_id  (hash_type_id)
#  index_hash_lists_on_name          (name) UNIQUE
#  index_hash_lists_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_type_id => hash_types.id)
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :hash_list do
    name { Faker::Lorem.word }
    # Factory_bot doesn't support singletons, so we have to check if the hash type exists before creating it
    hash_type { HashType.find_by(hashcat_mode: 0) || create(:md5) }
    metadata_fields_count { 0 }
    processed { false }
    salt { false }
    sensitive { true }
    separator { ":" }
    project

    after(:build) do |hash_list|
      hash_list.file.attach(
        io: Rails.root.join("spec/fixtures/hash_lists/example_hashes.txt").open,
        filename: "example_hashes.txt"
      )
    end
  end
end
