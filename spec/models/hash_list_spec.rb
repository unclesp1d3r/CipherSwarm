# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hash_lists
#
#  id                                                                                                                        :bigint           not null, primary key
#  description(Description of the hash list)                                                                                 :text
#  hash_items_count                                                                                                          :integer          default(0)
#  name(Name of the hash list)                                                                                               :string           not null, uniquely indexed
#  processed(Is the hash list processed into hash items?)                                                                    :boolean          default(FALSE), not null
#  sensitive(Is the hash list sensitive?)                                                                                    :boolean          default(FALSE), not null
#  separator(Separator used in the hash list file to separate the hash from the password or other metadata. Default is ":".) :string(1)        default(":"), not null
#  created_at                                                                                                                :datetime         not null
#  updated_at                                                                                                                :datetime         not null
#  creator_id(The user who created this hash list)                                                                           :bigint           indexed
#  hash_type_id                                                                                                              :bigint           not null, indexed
#  project_id(Project that the hash list belongs to)                                                                         :bigint           not null, indexed
#
# Indexes
#
#  index_hash_lists_on_creator_id    (creator_id)
#  index_hash_lists_on_hash_type_id  (hash_type_id)
#  index_hash_lists_on_name          (name) UNIQUE
#  index_hash_lists_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (hash_type_id => hash_types.id)
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe HashList do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:hash_items) }
    it { is_expected.to have_one_attached(:file) }
    it { is_expected.to belong_to(:hash_type) }
    it { is_expected.to belong_to(:creator).class_name("User").optional }
  end

  describe "validations" do
    subject { create(:hash_list) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:separator).is_equal_to(1).allow_blank }
  end

  describe "callbacks" do
    it { is_expected.to callback(:process_hash_list).after(:commit) }
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
    it { is_expected.to have_db_column(:sensitive).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:separator).of_type(:string).with_options(default: ":", null: false) }
  end

  describe "instance methods" do
    let(:hash_list) { create(:hash_list) }

    describe "#recent_cracks" do
      before do
        # Create cracks from different time periods
        create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: 2.hours.ago, plain_text: "password1")
        create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: 12.hours.ago, plain_text: "password2")
        create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: 25.hours.ago, plain_text: "password3")
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns cracked hashes from the last 24 hours" do
        recent = hash_list.recent_cracks
        expect(recent.count).to eq(2)
      end

      it "respects the limit parameter" do
        recent = hash_list.recent_cracks(limit: 1)
        expect(recent.count).to eq(1)
      end

      it "orders by cracked_time descending" do
        recent = hash_list.recent_cracks
        times = recent.map(&:cracked_time)
        expect(times).to eq(times.sort.reverse)
      end

      it "uses caching with 1-minute TTL" do
        allow(Rails.cache).to receive(:fetch).and_call_original
        hash_list.recent_cracks
        hash_list.recent_cracks
        # Cache.fetch should be called for caching
        expect(Rails.cache).to have_received(:fetch).at_least(:once)
      end
    end

    describe "#cracked_list" do
      before do
        create(:hash_item, hash_list: hash_list, cracked: true, plain_text: "pass1", cracked_time: 1.hour.ago)
        create(:hash_item, hash_list: hash_list, cracked: true, plain_text: "pass2", cracked_time: 2.hours.ago)
        create(:hash_item, hash_list: hash_list, cracked: false)
      end

      it "returns cracked hash:plain pairs joined by newlines" do
        result = hash_list.cracked_list
        lines = result.split("\n")
        expect(lines.length).to eq(2)
        expect(lines).to all(include(hash_list.separator))
      end
    end

    describe "#cracked_list_enum" do
      before do
        hash_list.hash_items.delete_all
      end

      it "returns an Enumerator" do
        expect(hash_list.cracked_list_enum).to be_a(Enumerator)
      end

      it "yields cracked hash items with default separator" do
        item1 = create(:hash_item, hash_list: hash_list, hash_value: "abc123", plain_text: "password1", cracked: true, cracked_time: 1.hour.ago)
        item2 = create(:hash_item, hash_list: hash_list, hash_value: "def456", plain_text: "password2", cracked: true, cracked_time: 2.hours.ago)

        result = hash_list.cracked_list_enum.to_a.join
        expect(result).to include("#{item1.hash_value}:#{item1.plain_text}")
        expect(result).to include("#{item2.hash_value}:#{item2.plain_text}")
      end

      it "does not include uncracked items" do
        create(:hash_item, hash_list: hash_list, hash_value: "abc123", plain_text: "password1", cracked: true, cracked_time: 1.hour.ago)
        uncracked = create(:hash_item, hash_list: hash_list, hash_value: "uncracked_hash", plain_text: nil, cracked: false)

        result = hash_list.cracked_list_enum.to_a.join
        expect(result).not_to include(uncracked.hash_value)
      end

      it "uses the configured separator between hash_value and plain_text" do
        hash_list.update_column(:separator, ";") # rubocop:disable Rails/SkipsModelValidations
        create(:hash_item, hash_list: hash_list, hash_value: "abc123", plain_text: "password1", cracked: true, cracked_time: 1.hour.ago)

        result = hash_list.cracked_list_enum.to_a.join
        expect(result).to include("abc123;password1")
        expect(result).not_to include("abc123:password1")
      end

      it "has no leading newline on first item and newlines between subsequent items" do
        create(:hash_item, hash_list: hash_list, hash_value: "abc123", plain_text: "pass1", cracked: true, cracked_time: 1.hour.ago)
        create(:hash_item, hash_list: hash_list, hash_value: "def456", plain_text: "pass2", cracked: true, cracked_time: 2.hours.ago)

        chunks = hash_list.cracked_list_enum.to_a
        full_output = chunks.join

        expect(full_output).not_to start_with("\n")
        lines = full_output.split("\n")
        expect(lines.length).to eq(2)
      end

      it "returns empty enumerator when no cracked items exist" do
        create(:hash_item, hash_list: hash_list, hash_value: "uncracked", plain_text: nil, cracked: false)

        result = hash_list.cracked_list_enum.to_a
        expect(result).to be_empty
      end
    end

    describe "#recent_cracks_count" do
      before do
        create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: 2.hours.ago, plain_text: "password1")
        create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: 12.hours.ago, plain_text: "password2")
        create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: 25.hours.ago, plain_text: "password3")
      end

      it "returns count of cracked hashes from the last 24 hours" do
        count = hash_list.recent_cracks_count
        expect(count).to eq(2)
      end

      it "uses caching with 1-minute TTL" do
        allow(Rails.cache).to receive(:fetch).and_call_original
        hash_list.recent_cracks_count
        hash_list.recent_cracks_count
        # Cache.fetch should be called for caching
        expect(Rails.cache).to have_received(:fetch).at_least(:once)
      end
    end
  end
end
