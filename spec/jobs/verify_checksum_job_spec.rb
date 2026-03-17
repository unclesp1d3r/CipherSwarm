# frozen_string_literal: true

require "rails_helper"

RSpec.describe VerifyChecksumJob do
  let(:word_list) { create(:word_list) }
  let(:temp_dir) { Rails.root.join("tmp/test_attack_resources") }
  let(:test_file_path) { File.join(temp_dir, "test-wordlist.txt") }
  let(:file_content) { "password123\nadmin\nletmein\n" }

  before do
    FileUtils.mkdir_p(temp_dir)
    File.write(test_file_path, file_content)
    word_list.update_columns(file_path: test_file_path, file_name: "test-wordlist.txt") # rubocop:disable Rails/SkipsModelValidations
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#perform" do
    context "when resource has a file_path with no checksum" do
      it "computes and saves checksum, marks as verified" do
        word_list.update_columns(checksum: nil, checksum_verified: false) # rubocop:disable Rails/SkipsModelValidations

        described_class.perform_now(word_list.id, "WordList")

        word_list.reload
        expect(word_list.checksum).to be_present
        expect(word_list.checksum).to eq(Digest::MD5.file(test_file_path).base64digest)
        expect(word_list.checksum_verified).to be true
      end
    end

    context "when checksum matches" do
      it "marks as verified" do
        expected = Digest::MD5.file(test_file_path).base64digest
        word_list.update_columns(checksum: expected, checksum_verified: false) # rubocop:disable Rails/SkipsModelValidations

        described_class.perform_now(word_list.id, "WordList")

        expect(word_list.reload.checksum_verified).to be true
      end
    end

    context "when checksum does not match" do
      it "logs error and sets checksum_verified false" do
        word_list.update_columns(checksum: "invalid_checksum", checksum_verified: true) # rubocop:disable Rails/SkipsModelValidations

        error_messages = []
        allow(Rails.logger).to receive(:error) { |*args, &block| error_messages << (block ? block.call : args.first) }

        described_class.perform_now(word_list.id, "WordList")

        expect(word_list.reload.checksum_verified).to be false
        expect(error_messages).to include(match(/ChecksumMismatch.*INTEGRITY FAILURE/))
      end
    end

    context "when file_path does not exist and no Active Storage fallback" do
      it "logs warning and returns" do
        # Purge AS attachment so fallback doesn't kick in
        word_list.file.purge if word_list.file.attached?
        word_list.update_columns(file_path: "/nonexistent/path.txt") # rubocop:disable Rails/SkipsModelValidations

        warn_messages = []
        allow(Rails.logger).to receive(:warn) { |*args, &block| warn_messages << (block ? block.call : args.first) }

        described_class.perform_now(word_list.id, "WordList")

        expect(warn_messages).to include(match(/No file found/))
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
