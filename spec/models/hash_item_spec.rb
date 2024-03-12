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
require 'rails_helper'

RSpec.describe HashItem, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
