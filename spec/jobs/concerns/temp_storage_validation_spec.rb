# frozen_string_literal: true

require "rails_helper"
require "sys/filesystem"

RSpec.describe TempStorageValidation do
  # Create a minimal test job that includes the concern
  let(:test_job_class) do
    Class.new(ApplicationJob) do
      include TempStorageValidation

      def perform(attachment)
        ensure_temp_storage_available!(attachment)
      end
    end
  end

  let(:blob) { double("ActiveStorage::Blob", byte_size: 100.megabytes, filename: "wordlist.txt") } # rubocop:disable RSpec/VerifiedDoubles
  let(:attachment) { double("ActiveStorage::Attached::One", blob: blob) } # rubocop:disable RSpec/VerifiedDoubles

  shared_context "with stubbed filesystem" do |bytes|
    before do
      fs_stat = instance_double(Sys::Filesystem::Stat, bytes_available: bytes)
      allow(Sys::Filesystem).to receive(:stat).with(Dir.tmpdir).and_return(fs_stat)
    end
  end

  context "when sufficient space is available" do
    include_context "with stubbed filesystem", 200.megabytes

    it "does not raise an error" do
      expect { test_job_class.new.perform(attachment) }.not_to raise_error
    end
  end

  context "when available space equals the blob size" do
    include_context "with stubbed filesystem", 100.megabytes

    it "raises InsufficientTempStorageError" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError)
    end
  end

  context "when insufficient space is available" do
    include_context "with stubbed filesystem", 50.megabytes

    it "raises InsufficientTempStorageError" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError)
    end

    it "includes the filename in the error message" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError, /wordlist\.txt/)
    end

    it "includes the required bytes in the error message" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError, /104857600 bytes required/)
    end

    it "includes the available bytes in the error message" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError, /52428800 bytes available/)
    end
  end

  context "when Sys::Filesystem raises an error" do
    before do
      allow(Sys::Filesystem).to receive(:stat).and_raise(Sys::Filesystem::Error, "permission denied")
    end

    it "logs a warning and does not block the job" do
      allow(Rails.logger).to receive(:warn)
      expect { test_job_class.new.perform(attachment) }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/\[TempStorage\].*permission denied/)
    end
  end
end
