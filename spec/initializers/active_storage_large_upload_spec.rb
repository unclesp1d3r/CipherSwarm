# frozen_string_literal: true

require "rails_helper"

# rubocop:disable RSpec/DescribeClass -- tests an initializer, not a class
RSpec.describe "Active Storage large upload support" do
  describe "Blob checksum validation" do
    it "allows nil checksum when checksum_skipped metadata is set" do
      blob = ActiveStorage::Blob.new(
        filename: "test.txt",
        byte_size: 100,
        checksum: nil,
        content_type: "text/plain",
        service_name: "test",
        metadata: { "checksum_skipped" => true }
      )
      expect(blob).to be_valid
    end

    it "requires checksum when checksum_skipped is not set" do
      blob = ActiveStorage::Blob.new(
        filename: "test.txt",
        byte_size: 100,
        checksum: nil,
        content_type: "text/plain",
        service_name: "test"
      )
      expect(blob).not_to be_valid
      expect(blob.errors[:checksum]).to include("can't be blank")
    end

    it "requires checksum when metadata is empty" do
      blob = ActiveStorage::Blob.new(
        filename: "test.txt",
        byte_size: 100,
        checksum: nil,
        content_type: "text/plain",
        service_name: "test",
        metadata: {}
      )
      expect(blob).not_to be_valid
      expect(blob.errors[:checksum]).to include("can't be blank")
    end

    it "preserves service_name presence validator" do
      validators = ActiveStorage::Blob.validators_on(:service_name)
      expect(validators).not_to be_empty
      expect(validators.first).to be_a(ActiveRecord::Validations::PresenceValidator)
    end

    it "accepts normal blobs with checksum present" do
      blob = ActiveStorage::Blob.new(
        filename: "test.txt",
        byte_size: 100,
        checksum: "abc123base64==",
        content_type: "text/plain",
        service_name: "test"
      )
      expect(blob).to be_valid
    end
  end
end
# rubocop:enable RSpec/DescribeClass
