# == Schema Information
#
# Table name: hash_items
#
#  id                                                :bigint           not null, primary key
#  cracked(Is the hash cracked?)                     :boolean          default(FALSE)
#  cracked_time(Time when the hash was cracked)      :datetime
#  hash_value(Hash value)                            :text             not null
#  metadata_fields(Metadata fields of the hash item) :string           is an Array
#  plain_text(Plaintext value of the hash)           :string
#  salt(Salt of the hash)                            :text
#  created_at                                        :datetime         not null
#  updated_at                                        :datetime         not null
#  hash_list_id                                      :bigint           not null, indexed
#
# Indexes
#
#  index_hash_items_on_hash_list_id  (hash_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_list_id => hash_lists.id)
#
FactoryBot.define do
  factory :hash_item do
    association :hash_list, factory: :basic_list
    cracked { false }
    plain_text { nil }
    cracked_time { "2024-03-09 15:28:14" }
    hash_value { "286755fad04869ca523320acce0dc6a4" }
    salt { nil }
  end
end
