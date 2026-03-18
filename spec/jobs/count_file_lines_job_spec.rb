# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe CountFileLinesJob do
  describe "job configuration" do
    it "uses the ingest queue" do
      expect(described_class.new.queue_name).to eq("ingest")
    end

    it "is configured to discard on RecordNotFound" do
      expect(described_class.rescue_handlers).to include(
        have_attributes(first: "ActiveRecord::RecordNotFound")
      )
    end

    it "is configured to retry on FileNotFoundError" do
      expect(described_class.rescue_handlers).to include(
        have_attributes(first: "ActiveStorage::FileNotFoundError")
      )
    end
  end

  describe "queuing" do
    it "enqueues the job on the ingest queue" do
      ActiveJob::Base.queue_adapter = :test
      expect { described_class.perform_later(1, "RuleList") }
        .to have_enqueued_job(described_class)
        .with(1, "RuleList")
        .on_queue("ingest")
    end
  end

  describe "#perform" do
    context "when the type is not in ALLOWED_TYPES" do
      it "raises InvalidTypeError with an informative message" do
        expect { described_class.new.perform(1, "User") }
          .to raise_error(CountFileLinesJob::InvalidTypeError, /Invalid type 'User'/)
      end

      it "is discarded by the job framework" do
        expect(described_class.rescue_handlers).to include(
          have_attributes(first: "CountFileLinesJob::InvalidTypeError")
        )
      end
    end

    context "when the record does not exist" do
      it "discards the job without raising an error" do
        expect { described_class.perform_now(-1, "RuleList") }.not_to raise_error
      end
    end

    context "when the record exists with a file" do
      let(:rule_list) do
        # Create as already processed to prevent callback from running job again
        rl = create(:rule_list, processed: true, line_count: 999)
        # Reset state for testing - use update_column to bypass callbacks
        rl.update_columns(processed: false, line_count: 0) # rubocop:disable Rails/SkipsModelValidations
        rl.reload
      end

      it "counts the lines in the file" do
        expect(rule_list.file).to be_attached

        expect { described_class.perform_now(rule_list.id, "RuleList") }
          .to change { rule_list.reload.line_count }.from(0)
      end

      it "marks the record as processed" do
        expect { described_class.perform_now(rule_list.id, "RuleList") }
          .to change { rule_list.reload.processed }.from(false).to(true)
      end
    end

    context "when the record is already processed" do
      let(:rule_list) do
        # Create as processed - the callback will have already run
        create(:rule_list, processed: true, line_count: 100)
      end

      it "does not update the line count" do
        expect { described_class.perform_now(rule_list.id, "RuleList") }
          .not_to change { rule_list.reload.line_count }
      end
    end

    context "when temp storage is insufficient" do
      let(:rule_list) do
        rl = create(:rule_list, processed: true, line_count: 999)
        rl.update_columns(processed: false, line_count: 0) # rubocop:disable Rails/SkipsModelValidations
        rl.reload
      end

      before do
        fs_stat = instance_double(Sys::Filesystem::Stat, bytes_available: 1.byte)
        allow(Sys::Filesystem).to receive(:stat).with(Dir.tmpdir).and_return(fs_stat)
      end

      it "raises InsufficientTempStorageError from the concern" do
        job = described_class.new
        expect { job.perform(rule_list.id, "RuleList") }
          .to raise_error(InsufficientTempStorageError)
      end

      it "does not update the record" do
        described_class.perform_now(rule_list.id, "RuleList")
        expect(rule_list.reload.processed).to be false
        expect(rule_list.reload.line_count).to eq(0)
      end
    end

    context "when the file is not attached" do
      let(:rule_list) do
        # Create with file, then purge it
        rl = create(:rule_list, processed: true, line_count: 100)
        rl.file.purge
        rl.update_columns(processed: false, line_count: 0) # rubocop:disable Rails/SkipsModelValidations
        rl.reload
      end

      it "raises an error for missing file" do
        expect { described_class.perform_now(rule_list.id, "RuleList") }.to raise_error(StandardError, /No file found/)
      end
    end
  end
end
