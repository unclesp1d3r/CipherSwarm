# frozen_string_literal: true

require "rails_helper"

RSpec.describe CountFileLinesJob, type: :job do
  include ActiveJob::TestHelper

  ActiveJob::Base.queue_adapter = :test
  let(:list) { create(:rule_list, file: nil) }

  describe "queuing" do
    subject(:job) { described_class.perform_later }

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "queues the job" do
      expect { job }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
    end

    it "is in high queue" do
      expect(described_class.new.queue_name).to eq("high")
    end

    it "executes the queued job" do
      expect { job }.to have_enqueued_job(described_class)
      perform_enqueued_jobs { job }
    end
  end

  describe "#perform" do
    context "when the list is not processed and has a file" do
      before do
        allow(list).to receive(:file).and_return(File.open("spec/fixtures/rule_lists/dive.rule"))
      end

      it "counts the number of lines in the file and updates the line_count attribute" do
        expect {
          described_class.new.perform(list.id, "RuleList")
          list.reload
        }.to change(list, :line_count).from(0).to(98676)
      end

      it "marks the list as processed and saves it" do
        expect {
          described_class.new.perform(list.id, "RuleList")
          list.reload
        }.to change(list, :processed).from(false).to(true)
      end
    end
  end
end
