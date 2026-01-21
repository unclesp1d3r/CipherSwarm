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
  end
end
