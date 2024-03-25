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
class HashItem < ApplicationRecord
  belongs_to :hash_list, touch: true
  validates_presence_of :hash_value
  validates_presence_of :plain_text, if: :cracked

  validates_uniqueness_of :hash_value, scope: [ :salt, :hash_list_id ]
end
