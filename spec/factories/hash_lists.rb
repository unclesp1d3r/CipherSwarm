# == Schema Information
#
# Table name: hash_lists
#
#  id                                                                                                                        :bigint           not null, primary key
#  description(Description of the hash list)                                                                                 :text
#  hash_mode(Hash mode of the hash list (hashcat mode))                                                                      :integer          not null, indexed
#  metadata_fields_count(Number of metadata fields in the hash list file. Default is 0.)                                     :integer          default(0), not null
#  name(Name of the hash list)                                                                                               :string           not null, indexed
#  sensitive(Is the hash list sensitive?)                                                                                    :boolean          default(FALSE)
#  separator(Separator used in the hash list file to separate the hash from the password or other metadata. Default is ":".) :string(1)        default(":"), not null
#  created_at                                                                                                                :datetime         not null
#  updated_at                                                                                                                :datetime         not null
#  project_id(Project that the hash list belongs to)                                                                         :bigint           not null, indexed
#
# Indexes
#
#  index_hash_lists_on_hash_mode   (hash_mode)
#  index_hash_lists_on_name        (name) UNIQUE
#  index_hash_lists_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :basic_list, :hash_list do
    name { "Basic List" }
    description { "Just a basic list" }
    file { nil }
    sensitive { false }
    hash_mode { 0 }
  end
end
