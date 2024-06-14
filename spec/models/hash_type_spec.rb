# frozen_string_literal: true

# == Schema Information
#
# Table name: hash_types
#
#  id                                          :bigint           not null, primary key
#  built_in(Whether the hash type is built-in) :boolean          default(FALSE), not null
#  category(The category of the hash type)     :integer          default("raw_hash"), not null
#  enabled(Whether the hash type is enabled)   :boolean          default(TRUE), not null
#  hashcat_mode(The hashcat mode number)       :integer          not null, indexed
#  is_slow(Whether the hash type is slow)      :boolean          default(FALSE), not null
#  name(The name of the hash type)             :string           not null, indexed
#  created_at                                  :datetime         not null
#  updated_at                                  :datetime         not null
#
# Indexes
#
#  index_hash_types_on_hashcat_mode  (hashcat_mode) UNIQUE
#  index_hash_types_on_name          (name) UNIQUE
#
require "rails_helper"

# rubocop:disable RSpec/LetSetup
RSpec.describe HashType, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:hash_lists).dependent(:restrict_with_error) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:hashcat_mode) }
  end

  describe "scopes" do
    describe ".enabled" do
      let!(:hash_type) { create(:hash_type, enabled: true) }
      let!(:disabled_hash_type) { create(:hash_type, enabled: false) }

      it "returns enabled hash types" do
        expect(described_class.enabled).to eq([hash_type])
      end
    end

    describe ".disabled" do
      let!(:hash_type) { create(:hash_type, enabled: true) }
      let!(:disabled_hash_type) { create(:hash_type, enabled: false) }

      it "returns disabled hash types" do
        expect(described_class.disabled).to eq([disabled_hash_type])
      end
    end

    describe ".slow" do
      let!(:slow_hash_type) { create(:hash_type, is_slow: true) }
      let!(:fast_hash_type) { create(:hash_type, is_slow: false) }

      it "returns slow hash types" do
        expect(described_class.slow).to eq([slow_hash_type])
      end
    end

    describe ".fast" do
      let!(:slow_hash_type) { create(:hash_type, is_slow: true) }
      let!(:fast_hash_type) { create(:hash_type, is_slow: false) }

      it "returns fast hash types" do
        expect(described_class.fast).to eq([fast_hash_type])
      end
    end

    describe ".built_in" do
      let!(:built_in_hash_type) { create(:hash_type, built_in: true) }
      let!(:custom_hash_type) { create(:hash_type, built_in: false) }

      it "returns built-in hash types" do
        expect(described_class.built_in).to eq([built_in_hash_type])
      end
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:name).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:hashcat_mode).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:category).of_type(:integer).with_options(default: :raw_hash, null: false) }
    it { is_expected.to have_db_column(:enabled).of_type(:boolean).with_options(default: true, null: false) }
    it { is_expected.to have_db_column(:is_slow).of_type(:boolean).with_options(default: false, null: false) }
    it { is_expected.to have_db_column(:built_in).of_type(:boolean).with_options(default: false, null: false) }
  end

  describe "is valid" do
    let(:hash_type) { create(:hash_type) }

    it "when all required attributes are present" do
      expect(hash_type).to be_valid
    end
  end
end
