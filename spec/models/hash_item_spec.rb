# frozen_string_literal: true

# == Schema Information
#
# Table name: hash_items
#
#  id                                                :bigint           not null, primary key
#  cracked(Is the hash cracked?)                     :boolean          default(FALSE), not null
#  cracked_time(Time when the hash was cracked)      :datetime
#  hash_value(Hash value)                            :text             not null, indexed => [salt, hash_list_id]
#  metadata_fields(Metadata fields of the hash item) :string           is an Array
#  plain_text(Plaintext value of the hash)           :string
#  salt(Salt of the hash)                            :text             indexed => [hash_value, hash_list_id]
#  created_at                                        :datetime         not null
#  updated_at                                        :datetime         not null
#  hash_list_id                                      :bigint           not null, indexed, indexed => [hash_value, salt]
#
# Indexes
#
#  index_hash_items_on_hash_list_id                          (hash_list_id)
#  index_hash_items_on_hash_value_and_salt_and_hash_list_id  (hash_value,salt,hash_list_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (hash_list_id => hash_lists.id)
#
require "rails_helper"

RSpec.describe HashItem do
  describe "validations" do
    it { is_expected.to validate_presence_of(:hash_value) }
    it { is_expected.to validate_length_of(:salt).is_at_most(255) }
    it { is_expected.to validate_length_of(:plain_text).is_at_most(255) }
    it { is_expected.to validate_length_of(:metadata_fields).is_at_most(255) }

    describe "validating uniqueness of hash value" do
      subject { build(:hash_item) }

      it { is_expected.to validate_uniqueness_of(:hash_value).scoped_to(%i[salt hash_list_id]) }
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:hash_list) }
  end
end
