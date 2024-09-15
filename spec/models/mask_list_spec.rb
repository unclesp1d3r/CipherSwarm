# frozen_string_literal: true

# == Schema Information
#
# Table name: mask_lists
#
#  id                                                  :bigint           not null, primary key
#  complexity_value(Total attemptable password values) :decimal(, )      default(0.0)
#  description(Description of the mask list)           :text
#  line_count(Number of lines in the mask list)        :bigint
#  name(Name of the mask list)                         :string(255)      not null, indexed
#  processed(Has the mask list been processed?)        :boolean          default(FALSE), not null, indexed
#  sensitive(Is the mask list sensitive?)              :boolean          default(FALSE), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#  creator_id(The user who created this list)          :bigint           indexed
#
# Indexes
#
#  index_mask_lists_on_creator_id  (creator_id)
#  index_mask_lists_on_name        (name) UNIQUE
#  index_mask_lists_on_processed   (processed)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
require "rails_helper"

RSpec.describe MaskList, type: :model do
  subject { create(:mask_list) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_numericality_of(:line_count).only_integer.is_greater_than_or_equal_to(0).allow_nil }
  end

  describe "associations" do
    it { is_expected.to have_and_belong_to_many(:projects) }
  end

  describe "file attachment" do
    it { is_expected.to have_one_attached(:file) }
  end

  describe "scopes" do
    describe ".sensitive" do
      it "returns only sensitive rule lists" do
        sensitive_mask_list = create(:mask_list, sensitive: true, name: "sensitive")
        create(:mask_list, sensitive: false, name: "not_sensitive")

        expect(described_class.sensitive).to eq([sensitive_mask_list])
      end
    end
  end
end
