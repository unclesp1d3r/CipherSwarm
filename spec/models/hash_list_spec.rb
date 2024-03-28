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
require 'rails_helper'

RSpec.describe HashList, type: :model do
  context 'associations' do
    it { should belong_to(:project) }
    it { should have_many(:hash_items) }
    it { should have_one_attached(:file) }
  end
  context 'validations' do
    subject { create(:hash_list) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:hash_mode) }
    it { should validate_presence_of(:project) }
    it { should validate_uniqueness_of(:name).scoped_to(:project_id).case_insensitive }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:separator).is_equal_to(1).allow_blank }
    it { should validate_numericality_of(:metadata_fields_count).is_greater_than_or_equal_to(0).only_integer }
    it { should define_enum_for(:hash_mode) }
  end
  context 'callbacks' do
    it { should callback(:process_hash_list).after(:save) }
    it { should callback(:update_status).after(:update) }
  end
  context 'scopes' do
    describe '.sensitive' do
      let!(:hash_list) { create(:hash_list, sensitive: true) }
      let!(:hash_list2) { create(:hash_list, sensitive: false) }
      it 'returns sensitive hash lists' do
        expect(HashList.sensitive).to eq([ hash_list ])
      end
    end
  end
  context 'database columns' do
    it { should have_db_column(:description).of_type(:text) }
    it { should have_db_column(:hash_mode).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:metadata_fields_count).of_type(:integer).with_options(default: 0, null: false) }
    it { should have_db_column(:sensitive).of_type(:boolean).with_options(default: false) }
    it { should have_db_column(:separator).of_type(:string).with_options(default: ':', null: false) }
  end
end
