# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe ProcessHashListJob do
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

    it "has a retry handler for FileNotFoundError" do
      handler = described_class.rescue_handlers.find { |h| h.first == "ActiveStorage::FileNotFoundError" }
      expect(handler).not_to be_nil
    end
  end

  describe "discard behavior" do
    it "discards job when hash list does not exist" do
      # Using perform_now should not raise when record is not found
      expect { described_class.perform_now(-999) }.not_to raise_error
    end

    it "does not create hash items when discarded" do
      initial_count = HashItem.count
      described_class.perform_now(-999)
      expect(HashItem.count).to eq(initial_count)
    end
  end

  describe "retry behavior" do
    it "is configured to handle FileNotFoundError retries" do
      # Verify retry configuration exists for FileNotFoundError
      handler = described_class.rescue_handlers.find { |h| h.first == "ActiveStorage::FileNotFoundError" }
      expect(handler).not_to be_nil
    end

    it "inherits retry on Deadlocked from ApplicationJob" do
      expect(described_class.rescue_handlers.map(&:first)).to include("ActiveRecord::Deadlocked")
    end
  end

  describe "queuing", :perform_enqueued do
    it "enqueues the job on the ingest queue" do
      ActiveJob::Base.queue_adapter = :test
      expect { described_class.perform_later(1) }
        .to have_enqueued_job(described_class)
        .with(1)
        .on_queue("ingest")
    end
  end

  describe "#perform" do
    context "when the hash list does not exist" do
      it "discards the job without raising an error" do
        expect { described_class.perform_now(-1) }.not_to raise_error
      end
    end

    context "when the hash list exists with a file" do
      let(:hash_list) do
        # Create hash_list as already processed to prevent callback from running
        # Then we'll reset it and test the job directly
        hl = create(:hash_list, processed: true)
        # Reset state for testing - use update_column to bypass callbacks
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      it "creates hash items from the file" do
        expect(hash_list.file).to be_attached
        expect(hash_list.processed).to be false

        expect { described_class.perform_now(hash_list.id) }
          .to change(HashItem, :count).by(1024)
      end

      it "marks the hash list as processed" do
        described_class.perform_now(hash_list.id)

        expect(hash_list.reload.processed).to be true
      end

      it "updates the hash_items_count" do
        described_class.perform_now(hash_list.id)

        expect(hash_list.reload.hash_items_count).to eq(1024)
      end
    end

    context "when the hash list is already processed" do
      let(:hash_list) { create(:hash_list, processed: true) }

      it "does not create additional hash items" do
        initial_count = HashItem.count

        described_class.perform_now(hash_list.id)

        expect(HashItem.count).to eq(initial_count)
      end
    end

    context "when called twice (atomic lock prevents duplicates)" do
      let(:hash_list) do
        hl = create(:hash_list, processed: true)
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      it "only processes once even if called twice" do
        described_class.perform_now(hash_list.id)
        first_count = HashItem.where(hash_list_id: hash_list.id).count

        # Second call should be a no-op because processed is now true
        described_class.perform_now(hash_list.id)
        expect(HashItem.where(hash_list_id: hash_list.id).count).to eq(first_count)
      end
    end

    context "when ingestion raises an error" do
      let(:hash_list) do
        hl = create(:hash_list, processed: true)
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      before do
        allow_any_instance_of(described_class).to receive(:ingest_hash_items).and_raise(StandardError, "file corrupt") # rubocop:disable RSpec/AnyInstance
      end

      it "rolls back the processed flag" do
        expect { described_class.perform_now(hash_list.id) }.to raise_error(StandardError, "file corrupt")
        expect(hash_list.reload.processed).to be false
      end

      it "re-raises the exception for retry" do
        expect { described_class.perform_now(hash_list.id) }.to raise_error(StandardError, "file corrupt")
      end
    end

    context "when retrying after a partial failure" do
      let(:hash_list) do
        hl = create(:hash_list, processed: true)
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      it "cleans up partial results before re-ingesting" do
        # Simulate partial results from a prior failed attempt
        create(:hash_item, hash_list: hash_list, hash_value: "partial_leftover")
        expect(HashItem.where(hash_list_id: hash_list.id).count).to eq(1)

        described_class.perform_now(hash_list.id)

        # Should have exactly the file contents, not file + partial leftovers
        expect(hash_list.reload.hash_items_count).to eq(1024)
        expect(HashItem.where(hash_list_id: hash_list.id).count).to eq(1024)
      end
    end

    context "when the atomic lock is already claimed" do
      let(:hash_list) do
        hl = create(:hash_list, processed: true)
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      it "returns early without processing when another job claimed the lock" do
        # Simulate a race: find() loads processed=false, but another job
        # atomically claims the lock before our update_all runs.
        allow(HashList).to receive(:find).and_wrap_original do |method, *args|
          result = method.call(*args)
          # Between find and update_all, another job claims the lock
          HashList.where(id: result.id, processed: false)
                  .update_all(processed: true) # rubocop:disable Rails/SkipsModelValidations
          result
        end

        expect { described_class.perform_now(hash_list.id) }
          .not_to change(HashItem, :count)
      end
    end

    context "when the hash list is deleted during processing" do
      let(:hash_list) do
        hl = create(:hash_list, processed: true)
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      it "raises RecordNotSaved when count update finds no record" do
        # Let ingest run normally, but delete the hash list after the last
        # process_batch call so the final update_all(hash_items_count:) returns 0.
        batch_call_count = 0
        allow_any_instance_of(described_class).to receive(:process_batch).and_wrap_original do |method, *args| # rubocop:disable RSpec/AnyInstance
          method.call(*args)
          batch_call_count += 1
          # File has 1024 lines, batch_size=1000 → 2 process_batch calls.
          # Delete the hash list after the final batch.
          HashList.where(id: hash_list.id).delete_all if batch_call_count == 2
        end

        expect { described_class.perform_now(hash_list.id) }
          .to raise_error(ActiveRecord::RecordNotSaved, /record may have been deleted/)
      end
    end

    context "when rollback fails during error handling" do
      let(:hash_list) do
        hl = create(:hash_list, processed: true)
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      it "logs rollback failure and re-raises the original exception" do
        allow_any_instance_of(described_class).to receive(:ingest_hash_items) # rubocop:disable RSpec/AnyInstance
          .and_raise(StandardError, "file corrupt")

        # Make the rollback update_all raise by intercepting HashList.where(id:)
        allow(HashList).to receive(:where).and_wrap_original do |method, *args|
          result = method.call(*args)
          if args == [{ id: hash_list.id }]
            allow(result).to receive(:update_all).with(processed: false)
              .and_raise(ActiveRecord::ConnectionNotEstablished, "DB connection lost")
          end
          result
        end

        expect { described_class.perform_now(hash_list.id) }
          .to raise_error(StandardError, "file corrupt")
      end
    end

    context "when the file contains only blank lines" do
      let(:hash_list) do
        hl = create(:hash_list, processed: true)
        hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
        HashItem.where(hash_list_id: hl.id).delete_all
        hl.reload
      end

      it "raises an error when no items are processed" do
        # Stub any ActiveStorage blob to return blank content
        blank_file = StringIO.new("\n\n  \n")
        allow_any_instance_of(ActiveStorage::Blob).to receive(:open).and_yield(blank_file) # rubocop:disable RSpec/AnyInstance

        expect { described_class.perform_now(hash_list.id) }
          .to raise_error(StandardError, /No hash items were processed/)
      end
    end
  end
end
