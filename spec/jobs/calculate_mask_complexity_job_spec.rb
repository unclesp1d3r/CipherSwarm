# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe CalculateMaskComplexityJob do
  describe "job configuration" do
    it "uses the ingest queue" do
      expect(described_class.new.queue_name).to eq("ingest")
    end

    it "is configured to discard on RecordNotFound" do
      expect(described_class.rescue_handlers).to include(
        have_attributes(first: "ActiveRecord::RecordNotFound")
      )
    end
  end

  describe "queuing" do
    it "enqueues the job on the ingest queue" do
      ActiveJob::Base.queue_adapter = :test
      expect { described_class.perform_later(1) }
        .to have_enqueued_job(described_class)
        .with(1)
        .on_queue("ingest")
    end
  end

  describe "#perform" do
    context "when the mask list does not exist" do
      it "discards the job without raising an error" do
        expect { described_class.perform_now(-1) }.not_to raise_error
      end
    end

    context "when the mask list exists with a file" do
      let(:mask_list) do
        # Create with non-zero complexity to prevent callback from enqueueing job
        ml = create(:mask_list, complexity_value: 999)
        # Reset complexity for testing - use update_column to bypass callbacks
        ml.update_column(:complexity_value, 0) # rubocop:disable Rails/SkipsModelValidations
        ml.reload
      end

      it "calculates and updates the complexity value" do
        expect(mask_list.file).to be_attached
        expect(mask_list.complexity_value).to eq(0)

        described_class.perform_now(mask_list.id)

        expect(mask_list.reload.complexity_value).to be > 0
      end
    end

    context "when the mask list has no file attached" do
      let(:mask_list) do
        # Create normally, then detach the file using update_column to bypass callbacks
        ml = create(:mask_list, complexity_value: 999)
        ml.file.purge
        ml.update_column(:complexity_value, 0) # rubocop:disable Rails/SkipsModelValidations
        ml.reload
      end

      it "does not change the complexity value" do
        expect { described_class.perform_now(mask_list.id) }
          .not_to change { mask_list.reload.complexity_value }
      end
    end

    context "when the mask list already has a complexity value" do
      let(:mask_list) do
        ml = create(:mask_list, complexity_value: 999)
        # Keep the non-zero complexity
        ml.reload
      end

      it "does not recalculate the complexity value" do
        expect { described_class.perform_now(mask_list.id) }
          .not_to change { mask_list.reload.complexity_value }
      end
    end
  end
end
