# frozen_string_literal: true

require "rails_helper"

RSpec.describe VerifyChecksumJob do
  include ActiveSupport::Testing::TimeHelpers

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
      it "logs error and returns" do
        # Purge AS attachment so fallback doesn't kick in
        word_list.file.purge if word_list.file.attached?
        word_list.update_columns(file_path: "/nonexistent/path.txt") # rubocop:disable Rails/SkipsModelValidations

        error_messages = []
        allow(Rails.logger).to receive(:error) { |*args, &block| error_messages << (block ? block.call : args.first) }

        described_class.perform_now(word_list.id, "WordList")

        expect(error_messages).to include(match(/FILE_NOT_FOUND.*WordList/))
      end

      it "touches updated_at to prevent immediate re-enqueue by cron sweep" do
        word_list.file.purge if word_list.file.attached?
        word_list.update_columns(file_path: "/nonexistent/path.txt", updated_at: 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations
        allow(Rails.logger).to receive(:error)

        freeze_time do
          described_class.perform_now(word_list.id, "WordList")
          expect(word_list.reload.updated_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    context "when an I/O error is raised during checksum computation" do
      let(:job_double) do
        instance_double(described_class, arguments: [word_list.id, "WordList"], job_id: "test-job-123")
      end

      it "IO_ERROR_DISCARD_HANDLER logs error with resource details" do
        error = Errno::ENOENT.new("No such file or directory - /mnt/data/missing.txt")

        error_messages = []
        allow(Rails.logger).to receive(:error) { |*args, &block| error_messages << (block ? block.call : args.first) }

        described_class::IO_ERROR_DISCARD_HANDLER.call(job_double, error)

        expect(error_messages).to include(match(/ChecksumVerify.*FILE_IO_FAILURE.*WordList##{word_list.id}/))
        expect(error_messages).to include(match(/Re-upload the resource or check storage mount/))
      end

      it "IO_ERROR_DISCARD_HANDLER includes job ID and error class" do
        error = Errno::EACCES.new("Permission denied - /mnt/data/locked.txt")

        error_messages = []
        allow(Rails.logger).to receive(:error) { |*args, &block| error_messages << (block ? block.call : args.first) }

        described_class::IO_ERROR_DISCARD_HANDLER.call(job_double, error)

        expect(error_messages).to include(match(/Job ID: test-job-123/))
        expect(error_messages).to include(match(/Errno::EACCES/))
      end

      it "IO_ERROR_DISCARD_HANDLER does not raise when logging fails" do
        error = Errno::EIO.new("I/O error")
        allow(Rails.logger).to receive(:error).and_raise(RuntimeError, "logging broken")

        expect { described_class::IO_ERROR_DISCARD_HANDLER.call(job_double, error) }.not_to raise_error
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

  describe "retry_on configuration" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
    end

    it "configures retry_on for Errno::EIO, Errno::ENOENT, and Errno::EACCES" do
      handled_exceptions = described_class.rescue_handlers.map(&:first)

      expect(handled_exceptions).to include("Errno::EIO")
      expect(handled_exceptions).to include("Errno::ENOENT")
      expect(handled_exceptions).to include("Errno::EACCES")
    end

    it "re-enqueues on Errno::EIO (retry before exhaustion)" do
      word_list.update_columns(checksum: nil, checksum_verified: false) # rubocop:disable Rails/SkipsModelValidations
      allow(Digest::MD5).to receive(:file).and_raise(Errno::EIO, "I/O error")

      expect { described_class.perform_now(word_list.id, "WordList") }
        .to have_enqueued_job(described_class).with(word_list.id, "WordList")
    end

    it "re-enqueues on Errno::ENOENT (retry before exhaustion)" do
      word_list.update_columns(checksum: nil, checksum_verified: false) # rubocop:disable Rails/SkipsModelValidations
      allow(Digest::MD5).to receive(:file).and_raise(Errno::ENOENT, "No such file")

      expect { described_class.perform_now(word_list.id, "WordList") }
        .to have_enqueued_job(described_class).with(word_list.id, "WordList")
    end

    it "re-enqueues on Errno::EACCES (retry before exhaustion)" do
      word_list.update_columns(checksum: nil, checksum_verified: false) # rubocop:disable Rails/SkipsModelValidations
      allow(Digest::MD5).to receive(:file).and_raise(Errno::EACCES, "Permission denied")

      expect { described_class.perform_now(word_list.id, "WordList") }
        .to have_enqueued_job(described_class).with(word_list.id, "WordList")
    end

    it "retries when file disappears between exist check and checksum (TOCTOU race)" do
      word_list.update_columns(checksum: nil, checksum_verified: false) # rubocop:disable Rails/SkipsModelValidations
      # File.exist? returns true (resolve_file_path passes), but Digest::MD5.file
      # raises ENOENT because the file was deleted between the two calls.
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(test_file_path).and_return(true)
      allow(Digest::MD5).to receive(:file).with(test_file_path).and_raise(Errno::ENOENT, "deleted mid-flight")

      expect { described_class.perform_now(word_list.id, "WordList") }
        .to have_enqueued_job(described_class).with(word_list.id, "WordList")
    end

    it "discards and calls handler after exhausting all 5 attempts" do
      word_list.update_columns(checksum: nil, checksum_verified: false) # rubocop:disable Rails/SkipsModelValidations
      allow(Digest::MD5).to receive(:file).and_raise(Errno::EACCES, "Permission denied")

      error_messages = []
      allow(Rails.logger).to receive(:error) { |*args, &block| error_messages << (block ? block.call : args.first) }

      # Simulate exhausted retries by setting exception_executions to the max
      job = described_class.new(word_list.id, "WordList")
      job.exception_executions["[Errno::EIO, Errno::ENOENT, Errno::EACCES]"] = 4

      expect { job.perform_now }
        .not_to have_enqueued_job(described_class)

      expect(error_messages).to include(match(/FILE_IO_FAILURE/))
    end
  end
end
