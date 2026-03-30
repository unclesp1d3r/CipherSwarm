# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe RequeueUnverifiedResourcesJob do
  include ActiveSupport::Testing::TimeHelpers

  describe "#perform" do
    let(:job) { described_class.new }

    before do
      allow(ApplicationConfig).to receive(:checksum_verification_retry_threshold).and_return(6.hours)
    end

    describe "word list requeuing" do
      it "enqueues VerifyChecksumJob for stale unverified word lists" do
        resource = create(:word_list, checksum_verified: false)
        resource.update_column(:updated_at, 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).to have_received(:perform_later).with(resource.id, "WordList")
      end

      it "touches updated_at on enqueue to prevent re-enqueuing before next threshold" do
        resource = create(:word_list, checksum_verified: false)
        resource.update_column(:updated_at, 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations

        allow(VerifyChecksumJob).to receive(:perform_later)

        freeze_time do
          job.perform
          expect(resource.reload.updated_at).to be_within(1.second).of(Time.current)
        end
      end

      it "does not enqueue for recently updated unverified word lists" do
        create(:word_list, checksum_verified: false)
        # updated_at defaults to now, which is within the 6-hour threshold

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).not_to have_received(:perform_later)
      end

      it "does not enqueue for verified word lists even if old" do
        resource = create(:word_list, checksum_verified: true)
        resource.update_column(:updated_at, 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).not_to have_received(:perform_later)
      end

      it "handles errors gracefully" do
        allow(WordList).to receive(:checksum_unverified).and_raise(StandardError.new("Database error"))
        allow(Rails.logger).to receive(:error)

        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Error requeuing WordList/)
      end
    end

    describe "rule list requeuing" do
      it "enqueues VerifyChecksumJob for stale unverified rule lists" do
        resource = create(:rule_list, checksum_verified: false)
        resource.update_column(:updated_at, 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).to have_received(:perform_later).with(resource.id, "RuleList")
      end

      it "does not enqueue for recently updated unverified rule lists" do
        create(:rule_list, checksum_verified: false)

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).not_to have_received(:perform_later)
      end

      it "does not enqueue for verified rule lists even if old" do
        resource = create(:rule_list, checksum_verified: true)
        resource.update_column(:updated_at, 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).not_to have_received(:perform_later)
      end

      it "handles errors gracefully" do
        allow(RuleList).to receive(:checksum_unverified).and_raise(StandardError.new("Database error"))
        allow(Rails.logger).to receive(:error)

        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Error requeuing RuleList/)
      end
    end

    describe "mask list requeuing" do
      it "enqueues VerifyChecksumJob for stale unverified mask lists" do
        resource = create(:mask_list, checksum_verified: false)
        resource.update_column(:updated_at, 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).to have_received(:perform_later).with(resource.id, "MaskList")
      end

      it "does not enqueue for recently updated unverified mask lists" do
        create(:mask_list, checksum_verified: false)

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).not_to have_received(:perform_later)
      end

      it "does not enqueue for verified mask lists even if old" do
        resource = create(:mask_list, checksum_verified: true)
        resource.update_column(:updated_at, 7.hours.ago) # rubocop:disable Rails/SkipsModelValidations

        allow(VerifyChecksumJob).to receive(:perform_later)

        job.perform

        expect(VerifyChecksumJob).not_to have_received(:perform_later)
      end

      it "handles errors gracefully" do
        allow(MaskList).to receive(:checksum_unverified).and_raise(StandardError.new("Database error"))
        allow(Rails.logger).to receive(:error)

        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Error requeuing MaskList/)
      end
    end

    it "is enqueued in the low queue" do
      expect(described_class.new.queue_name).to eq("low")
    end

    describe "sweep summary" do
      it "logs success when all resource types processed without error" do
        allow(Rails.logger).to receive(:info)

        job.perform

        expect(Rails.logger).to have_received(:info)
          .with("[RequeueUnverified] Sweep complete — all resource types processed successfully")
      end

      it "reports a summary when requeue operations fail" do
        allow(WordList).to receive(:checksum_unverified).and_raise(StandardError.new("DB error"))
        allow(Rails.logger).to receive(:error)

        job.perform

        expect(Rails.logger).to have_received(:error).with(/Requeue completed with 1 failure.*word_lists/)
      end

      it "includes backtrace in error logs" do
        allow(WordList).to receive(:checksum_unverified).and_raise(StandardError.new("DB error"))
        allow(Rails.logger).to receive(:error)

        job.perform

        expect(Rails.logger).to have_received(:error).with(/Backtrace:/).at_least(:once)
      end
    end
  end
end
