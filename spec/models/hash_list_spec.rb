# frozen_string_literal: true

# == Schema Information
#
# Table name: hash_lists
#
#  id                                                                                                                        :bigint           not null, primary key
#  description(Description of the hash list)                                                                                 :text
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
require "rails_helper"

RSpec.describe HashList do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:hash_items) }
    it { is_expected.to have_one_attached(:file) }
    it { is_expected.to belong_to(:hash_type) }
  end

  describe "validations" do
    subject { create(:hash_list) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:separator).is_equal_to(1).allow_blank }
    it { is_expected.to validate_numericality_of(:metadata_fields_count).is_greater_than_or_equal_to(0).only_integer }
  end

  describe "callbacks" do
    it { is_expected.to callback(:process_hash_list).after(:save) }
  end

  describe "scopes" do
    describe ".sensitive" do
      let!(:sensitive_hash_list) { create(:hash_list, sensitive: true, name: "sensitive_hash_list") }
      let!(:public_hash_list) { create(:hash_list, sensitive: false, name: "public_hash_list") }

      it "returns sensitive hash lists" do
        expect(described_class.sensitive).to eq([sensitive_hash_list])
      end

      it "does not return non-sensitive hash lists" do
        expect(described_class.sensitive).not_to include(public_hash_list)
      end
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:description).of_type(:text) }
    it { is_expected.to have_db_column(:metadata_fields_count).of_type(:integer).with_options(default: 0, null: false) }
    it { is_expected.to have_db_column(:sensitive).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:separator).of_type(:string).with_options(default: ":", null: false) }
  end
end
