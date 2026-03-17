# frozen_string_literal: true

require "rails_helper"

RSpec.describe VerifyChecksumJob do
  let(:word_list) { create(:word_list) }

  describe "#perform" do
    context "when blob has a valid checksum" do
      it "marks the resource as checksum_verified" do
        word_list.update!(checksum_verified: false)

        described_class.perform_now(word_list.id, "WordList")

        expect(word_list.reload.checksum_verified).to be true
      end
    end

    context "when blob has checksum_skipped metadata" do
      it "computes checksum, updates blob, and marks as verified" do
        blob = word_list.file.blob
        blob.update!(checksum: nil, metadata: { "checksum_skipped" => true })
        word_list.update!(checksum_verified: false)

        described_class.perform_now(word_list.id, "WordList")

        blob.reload
        expect(blob.checksum).to be_present
        expect(blob.metadata).not_to include("checksum_skipped")
        expect(word_list.reload.checksum_verified).to be true
      end
    end

    context "when computed checksum does not match stored checksum" do
      it "logs warning and leaves checksum_verified false" do
        word_list.file.blob.update_column(:checksum, "invalid_checksum") # rubocop:disable Rails/SkipsModelValidations -- intentional: set invalid checksum without validation
        word_list.update!(checksum_verified: false)

        allow(Rails.logger).to receive(:warn)
        described_class.perform_now(word_list.id, "WordList")

        expect(word_list.reload.checksum_verified).to be false
        expect(Rails.logger).to have_received(:warn)
      end
    end

    context "when record is not found" do
      it "discards the job without raising" do
        expect { described_class.perform_now(0, "WordList") }.not_to raise_error
      end
    end

    context "with an invalid resource type" do
      it "raises ArgumentError" do
        expect { described_class.perform_now(1, "InvalidModel") }.to raise_error(ArgumentError, /Invalid resource type/)
      end
    end

    context "with a valid but disallowed resource type" do
      it "raises ArgumentError" do
        expect { described_class.perform_now(1, "User") }.to raise_error(ArgumentError, /Invalid resource type/)
      end
    end
  end
end
