# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe BroadcastRecentCracksJob do
  include ActiveJob::TestHelper

  ActiveJob::Base.queue_adapter = :test

  describe "queuing" do
    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "enqueues on the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "queues the job" do
      expect { described_class.perform_later(1) }
        .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
    end
  end

  describe "#perform" do
    let(:project) { create(:project) }
    let(:campaign) { create(:campaign, project: project) }

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "delegates to Campaign#broadcast_recent_cracks_update" do
      allow(Campaign).to receive(:find).with(campaign.id).and_return(campaign)
      allow(campaign).to receive(:broadcast_recent_cracks_update)

      described_class.new.perform(campaign.id)

      expect(campaign).to have_received(:broadcast_recent_cracks_update)
    end

    it "discards silently when the campaign no longer exists" do
      non_existent_id = 999_999_999

      expect {
        perform_enqueued_jobs { described_class.perform_later(non_existent_id) }
      }.not_to raise_error
    end
  end
end
