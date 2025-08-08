# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe ProcessHashListJob do
  include ActiveJob::TestHelper

  ActiveJob::Base.queue_adapter = :test
  let(:hash_list) { create(:hash_list, file: nil) }

  describe "queuing" do
    subject(:job) { described_class.perform_later(1) }

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "queues the job" do
      expect { job }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
    end

    it "is in ingest queue" do
      expect(described_class.new.queue_name).to eq("ingest")
    end

    it "executes the queued job" do
      expect { job }.to have_enqueued_job(described_class)
      perform_enqueued_jobs { job }
    end
  end

  describe "#perform" do
    before do
      allow(hash_list).to receive(:file).and_return(File.open("spec/fixtures/hash_lists/example_hashes.txt"))
    end

    it "creates hash items from the hash list file" do
      expect {
        described_class.new.perform(hash_list.id)
        hash_list.reload
      }.to change(HashItem, :count).by(1024)

      expect(hash_list.reload.processed).to be true
    end

    context "when the hash list is already processed" do
      let(:hash_list) { create(:hash_list, processed: true) }

      it "does not create hash items if the hash list is already processed" do
        expect { described_class.new.perform(hash_list.id) }.not_to change(HashItem, :count)
      end
    end
  end
end
