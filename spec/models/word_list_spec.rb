# == Schema Information
#
# Table name: word_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the word list)    :text
#  line_count(Number of lines in the word list) :integer
#  name(Name of the word list)                  :string           indexed
#  processed                                    :boolean          default(FALSE), indexed
#  sensitive(Is the word list sensitive?)       :boolean
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#
# Indexes
#
#  index_word_lists_on_name       (name) UNIQUE
#  index_word_lists_on_processed  (processed)
#
require 'rails_helper'

RSpec.describe WordList, type: :model do
  subject { create(:word_list) }

  context 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_numericality_of(:line_count).only_integer.is_greater_than_or_equal_to(0).allow_nil }
  end

  context 'associations' do
    it { is_expected.to have_and_belong_to_many(:projects) }
  end

  context 'file attachment' do
    it { is_expected.to have_one_attached(:file) }
  end

  context 'scopes' do
    describe '.sensitive' do
      it 'returns only sensitive rule lists' do
        sensitive_word_list = create(:word_list, sensitive: true)
        create(:rule_list, sensitive: false)

        expect(described_class.sensitive).to eq([ sensitive_word_list ])
      end
    end
  end
end
