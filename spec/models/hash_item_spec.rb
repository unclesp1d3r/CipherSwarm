# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hash_items
#
#  id                                                                   :bigint           not null, primary key
#  cracked(Is the hash cracked?)                                        :boolean          default(FALSE), not null, indexed => [hash_value_digest]
#  cracked_time(Time when the hash was cracked)                         :datetime         indexed
#  hash_value(Hash value)                                               :text             not null
#  hash_value_digest(MD5 fingerprint of hash_value for B-tree indexing) :string(32)       not null, indexed => [cracked], indexed => [hash_list_id]
#  metadata(Optional metadata fields for the hash item.)                :jsonb            not null
#  plain_text(Plaintext value of the hash)                              :string
#  salt(Salt of the hash)                                               :text
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  attack_id(The attack that cracked this hash)                         :bigint           indexed, indexed => [hash_list_id]
#  hash_list_id                                                         :bigint           not null, indexed, indexed => [attack_id], indexed => [hash_value_digest]
#
# Indexes
#
#  index_hash_items_on_attack_id                           (attack_id)
#  index_hash_items_on_cracked_time                        (cracked_time)
#  index_hash_items_on_hash_list_id                        (hash_list_id)
#  index_hash_items_on_hash_list_id_and_attack_id          (hash_list_id,attack_id)
#  index_hash_items_on_hash_value_digest_and_cracked       (hash_value_digest,cracked)
#  index_hash_items_on_hash_value_digest_and_hash_list_id  (hash_value_digest,hash_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (attack_id => attacks.id) ON DELETE => nullify
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe HashItem do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  describe "validations" do
    it { is_expected.to validate_presence_of(:hash_value) }
    it { is_expected.to validate_length_of(:salt).is_at_most(255) }
    it { is_expected.to validate_length_of(:plain_text).is_at_most(255) }
    it { is_expected.to validate_length_of(:metadata).is_at_most(255) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:hash_list) }
  end

  describe "broadcast_recent_cracks_update" do
    let(:project) { create(:project) }
    let(:campaign) { create(:campaign, project: project) }
    let(:hash_list) { campaign.hash_list }
    let(:hash_item) { create(:hash_item, hash_list: hash_list, plain_text: nil) }

    # Test env normally uses :null_store, which always reports the cache key
    # was NOT written. We swap to :memory_store so the SET NX EX debounce
    # behavior is observable.
    #
    # queue_adapter is process-global; restore it after each example so this
    # group cannot leak state into specs that run after it.
    around do |example|
      previous_cache = Rails.cache
      previous_queue_adapter = ActiveJob::Base.queue_adapter
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
      example.run
    ensure
      clear_enqueued_jobs
      ActiveJob::Base.queue_adapter = previous_queue_adapter
      Rails.cache = previous_cache
    end

    it "enqueues BroadcastRecentCracksJob on first crack within window" do
      expect {
        hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
      }.to have_enqueued_job(BroadcastRecentCracksJob).with(campaign.id)
    end

    it "does not enqueue a second job within the 5-second debounce window" do
      second = create(:hash_item, hash_list: hash_list, plain_text: nil)

      freeze_time do
        hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
        clear_enqueued_jobs

        expect {
          second.update!(cracked: true, plain_text: "qwerty", cracked_time: Time.current)
        }.not_to have_enqueued_job(BroadcastRecentCracksJob)
      end
    end

    it "enqueues again after the debounce window expires" do
      hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
      second = create(:hash_item, hash_list: hash_list, plain_text: nil)
      clear_enqueued_jobs

      travel(HashItem::BROADCAST_DEBOUNCE_WINDOW + 1.second) do
        expect {
          second.update!(cracked: true, plain_text: "qwerty", cracked_time: Time.current)
        }.to have_enqueued_job(BroadcastRecentCracksJob).with(campaign.id)
      end
    end

    it "schedules the broadcast at the trailing edge of the debounce window" do
      freeze_time do
        expect {
          hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
        }.to have_enqueued_job(BroadcastRecentCracksJob)
          .with(campaign.id)
          .at(HashItem::BROADCAST_DEBOUNCE_WINDOW.from_now)
      end
    end

    it "debounces per campaign — sibling campaigns get independent windows" do
      second_campaign = create(:campaign, project: project, hash_list: hash_list)
      clear_enqueued_jobs

      expect {
        hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
      }.to have_enqueued_job(BroadcastRecentCracksJob).exactly(:twice)

      broadcast_jobs = enqueued_jobs.select { |j| j[:job] == BroadcastRecentCracksJob }
      expect(broadcast_jobs.map { |j| j[:args].first }).to contain_exactly(campaign.id, second_campaign.id)
    end

    it "does not enqueue when cracked did not transition false → true" do
      hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
      clear_enqueued_jobs

      expect {
        hash_item.update!(plain_text: "different")
      }.not_to have_enqueued_job(BroadcastRecentCracksJob)
    end

    it "logs and swallows cache fetch failures without raising" do
      allow(Rails.cache).to receive(:fetch).and_raise(StandardError.new("redis down"))
      allow(Rails.logger).to receive(:error)

      expect {
        hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
      }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/Failed to load campaigns for recent cracks broadcast/)
    end

    it "continues enqueuing siblings when one campaign's debounce write fails" do
      second_campaign = create(:campaign, project: project, hash_list: hash_list)
      allow(Rails.cache).to receive(:write).and_call_original
      allow(Rails.cache).to receive(:write)
        .with("broadcast_recent_cracks:#{hash_list.id}:#{campaign.id}", any_args)
        .and_raise(StandardError.new("transient redis hiccup"))
      allow(Rails.logger).to receive(:error)

      expect {
        hash_item.update!(cracked: true, plain_text: "password", cracked_time: Time.current)
      }.to have_enqueued_job(BroadcastRecentCracksJob).with(second_campaign.id)
      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue recent cracks broadcast for campaign #{campaign.id}/)
    end
  end
end
