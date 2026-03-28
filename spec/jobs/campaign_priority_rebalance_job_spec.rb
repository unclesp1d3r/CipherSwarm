# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe CampaignPriorityRebalanceJob do
  include ActiveJob::TestHelper

  ActiveJob::Base.queue_adapter = :test

  describe "queuing" do
    subject(:job) { described_class.perform_later(1) }

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "queues the job" do
      expect { job }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
    end

    it "is in high priority queue" do
      expect(described_class.new.queue_name).to eq("high")
    end
  end

  describe "#perform" do
    let(:project) { create(:project) }
    let(:campaign) { create(:campaign, project: project, priority: :high) }

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    context "when the campaign has incomplete attacks with uncracked hashes" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign) }

      before do
        create(:hash_item, hash_list: campaign.hash_list, plain_text: nil)
      end

      it "calls TaskPreemptionService for each incomplete attack" do
        service = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).with(attack).and_return(service)
        allow(service).to receive(:preempt_if_needed)

        described_class.new.perform(campaign.id)

        expect(service).to have_received(:preempt_if_needed)
      end
    end

    context "when the attack has zero uncracked count" do
      before do
        create(:dictionary_attack, campaign: campaign)
        allow_any_instance_of(HashList).to receive(:uncracked_count).and_return(0) # rubocop:disable RSpec/AnyInstance
      end

      it "skips preemption for that attack" do
        allow(TaskPreemptionService).to receive(:new)

        described_class.new.perform(campaign.id)

        expect(TaskPreemptionService).not_to have_received(:new)
      end
    end

    context "when a per-attack error occurs" do
      let!(:failing_attack) { create(:dictionary_attack, campaign: campaign) }
      let!(:succeeding_attack) { create(:dictionary_attack, campaign: campaign) }

      before do
        create(:hash_item, hash_list: campaign.hash_list, plain_text: nil)
      end

      it "logs the error with backtrace and continues with the next attack" do
        failing_service = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).with(failing_attack).and_return(failing_service)
        allow(failing_service).to receive(:preempt_if_needed).and_raise(StandardError.new("boom"))

        succeeding_service = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).with(succeeding_attack).and_return(succeeding_service)
        allow(succeeding_service).to receive(:preempt_if_needed)

        allow(Rails.logger).to receive(:error)

        described_class.new.perform(campaign.id)

        expect(Rails.logger).to have_received(:error).with(/Error preempting tasks for attack #{failing_attack.id}.*Backtrace:/)
        expect(succeeding_service).to have_received(:preempt_if_needed)
      end
    end

    context "when the campaign no longer exists" do
      it "discards the job without raising" do
        non_existent_id = 999_999_999

        expect {
          perform_enqueued_jobs { described_class.perform_later(non_existent_id) }
        }.not_to raise_error
      end

      it "does not log a TaskRebalance error" do
        non_existent_id = 999_999_999
        allow(Rails.logger).to receive(:error)

        perform_enqueued_jobs { described_class.perform_later(non_existent_id) }

        expect(Rails.logger).not_to have_received(:error).with(/\[TaskRebalance\]/)
      end
    end

    context "when an unexpected error occurs outside the attack loop" do
      it "propagates the error for Sidekiq retry" do
        allow(Campaign).to receive(:find).with(campaign.id).and_return(campaign)
        allow(campaign).to receive_message_chain(:attacks, :awaiting_assignment, :includes).and_raise(StandardError.new("connection lost")) # rubocop:disable RSpec/MessageChain

        expect { described_class.new.perform(campaign.id) }.to raise_error(StandardError, "connection lost")
      end
    end

    context "when a per-attack database error occurs" do
      let!(:attack) { create(:dictionary_attack, campaign: campaign) }

      before do
        create(:hash_item, hash_list: campaign.hash_list, plain_text: nil)
      end

      it "propagates ConnectionNotEstablished for Sidekiq retry" do
        service = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).with(attack).and_return(service)
        allow(service).to receive(:preempt_if_needed)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new("connection lost"))

        expect { described_class.new.perform(campaign.id) }
          .to raise_error(ActiveRecord::ConnectionNotEstablished)
      end

      it "propagates StatementInvalid wrapping PG::ConnectionBad for Sidekiq retry" do
        service = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).with(attack).and_return(service)

        # Build a StatementInvalid with PG::ConnectionBad as its cause via exception chaining
        allow(service).to receive(:preempt_if_needed) do
          raise PG::ConnectionBad, "connection lost"
        rescue PG::ConnectionBad
          raise ActiveRecord::StatementInvalid, "PG::ConnectionBad: connection lost"
        end

        expect { described_class.new.perform(campaign.id) }
          .to raise_error(ActiveRecord::StatementInvalid)
      end

      it "logs and skips StatementInvalid without a connection cause" do
        service = instance_double(TaskPreemptionService)
        allow(TaskPreemptionService).to receive(:new).with(attack).and_return(service)
        allow(service).to receive(:preempt_if_needed)
          .and_raise(ActiveRecord::StatementInvalid.new("PG::UndefinedTable"))
        allow(Rails.logger).to receive(:error)

        expect { described_class.new.perform(campaign.id) }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/SQL error preempting tasks for attack #{attack.id}/)
      end
    end

    context "when the campaign has no incomplete attacks" do
      before do
        create(:dictionary_attack, campaign: campaign, state: "completed")
      end

      it "completes without calling TaskPreemptionService" do
        allow(TaskPreemptionService).to receive(:new)

        described_class.new.perform(campaign.id)

        expect(TaskPreemptionService).not_to have_received(:new)
      end
    end
  end
end
