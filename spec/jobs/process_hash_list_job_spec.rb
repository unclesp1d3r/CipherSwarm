# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessHashListJob, type: :job do
  include ActiveJob::TestHelper

  ActiveJob::Base.queue_adapter = :test

  describe "queuing" do
    subject(:job) { described_class.perform_later }

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it 'queues the job' do
      expect { job }
        .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
    end

    it 'is in low priority queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'executes the queued job' do
      expect { job }.to have_enqueued_job(described_class)
      perform_enqueued_jobs { job }
    end
  end

  describe '#perform' do
    let(:job) { described_class.new }

    it 'creates hash items from the hash list file' do
      hash_list = create(:hash_list)
      allow(HashList).to receive(:find).with(hash_list.id).and_return(hash_list)

      expect {
        job.perform(hash_list.id)
      }.to change(HashItem, :count).by(7)

      expect(hash_list.reload.processed).to be true
    end

    context 'when the hash list is already processed' do
      let(:hash_list) { create(:hash_list, processed: true) }

      it 'does not create hash items if the hash list is already processed' do
        expect { job.perform(hash_list.id) }.not_to change(HashItem, :count)
      end
    end
  end
end
