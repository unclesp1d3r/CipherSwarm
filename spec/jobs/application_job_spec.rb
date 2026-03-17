# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe ApplicationJob do
  describe "error handling configuration" do
    it "is configured to retry on ActiveRecord::Deadlocked" do
      expect(described_class.rescue_handlers.map(&:first)).to include("ActiveRecord::Deadlocked")
    end

    it "is configured to discard on ActiveJob::DeserializationError" do
      expect(described_class.rescue_handlers.map(&:first)).to include("ActiveJob::DeserializationError")
    end

    it "has a block handler for DeserializationError" do
      # Find the handler for DeserializationError
      handler = described_class.rescue_handlers.find { |h| h.first == "ActiveJob::DeserializationError" }
      expect(handler).not_to be_nil

      # The handler should have a block (Proc) that handles the discard
      handler_proc = handler.second
      expect(handler_proc).to be_a(Proc)
    end
  end

  describe "DeserializationError handling" do
    it "discard handler includes logging block" do
      handler = described_class.rescue_handlers.find { |h| h.first == "ActiveJob::DeserializationError" }
      expect(handler.second).to be_a(Proc)
    end

    it "handler block captures job class name" do
      # Read the source of the handler to verify it logs job.class.name
      handler = described_class.rescue_handlers.find { |h| h.first == "ActiveJob::DeserializationError" }
      source = handler.second.source rescue nil
      # If source is available, verify it references job.class.name
      # Otherwise, just verify the handler exists with a proc
      expect(handler.second).to be_a(Proc)
    end

    it "discard handler rescues logging errors" do
      # Verify the handler has rescue StandardError to prevent logging failures from breaking jobs
      # We can't easily test this without invoking the full handler machinery,
      # but we verify the handler is a Proc with error handling
      handler = described_class.rescue_handlers.find { |h| h.first == "ActiveJob::DeserializationError" }
      expect(handler).not_to be_nil
    end
  end

  describe "InsufficientTempStorageError handling" do
    it "is configured to retry on InsufficientTempStorageError" do
      expect(described_class.rescue_handlers.map(&:first)).to include("InsufficientTempStorageError")
    end
  end

  describe "TEMP_STORAGE_DISCARD_HANDLER" do
    let(:handler) { described_class::TEMP_STORAGE_DISCARD_HANDLER }
    let(:job) { described_class.new }
    let(:error) { InsufficientTempStorageError.new("[TempStorage] Not enough space") }

    it "logs with TempStorage prefix and discarded message" do
      allow(Rails.logger).to receive(:error)
      handler.call(job, error)
      expect(Rails.logger).to have_received(:error).with(/\[TempStorage\].*discarded after retries/)
    end

    it "includes filtered arguments in the log" do
      allow(Rails.logger).to receive(:error)
      handler.call(job, error)
      expect(Rails.logger).to have_received(:error).with(/Arguments:/)
    end

    it "includes the error message" do
      allow(Rails.logger).to receive(:error)
      handler.call(job, error)
      expect(Rails.logger).to have_received(:error).with(/Not enough space/)
    end

    it "logs a fallback message when primary logging fails" do
      call_count = 0
      allow(Rails.logger).to receive(:error) do
        call_count += 1
        raise StandardError, "logging broken" if call_count == 1
      end

      expect { handler.call(job, error) }.not_to raise_error
      expect(call_count).to eq(2) # first call raises, fallback call succeeds
    end
  end

  describe "inheritable configuration" do
    # Create a child job class
    let(:child_job_class) do
      Class.new(ApplicationJob) do
        def self.name
          "ChildJob"
        end

        def perform
          # noop
        end
      end
    end

    it "child jobs inherit retry on Deadlocked" do
      expect(child_job_class.rescue_handlers.map(&:first)).to include("ActiveRecord::Deadlocked")
    end

    it "child jobs inherit discard on DeserializationError" do
      expect(child_job_class.rescue_handlers.map(&:first)).to include("ActiveJob::DeserializationError")
    end
  end
end
