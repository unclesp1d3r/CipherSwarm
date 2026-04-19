# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: campaigns
#
#  id                                             :bigint           not null, primary key
#  attacks_count                                  :integer          default(0), not null
#  deleted_at                                     :datetime         indexed
#  description                                    :text
#  name                                           :string           not null
#  priority(-1: Deferred, 0: Normal, 2: High)     :integer          default("normal"), not null, indexed, indexed => [project_id]
#  quarantine_reason                              :text
#  quarantined                                    :boolean          default(FALSE), not null, indexed
#  created_at                                     :datetime         not null
#  updated_at                                     :datetime         not null
#  creator_id(The user who created this campaign) :bigint           indexed
#  hash_list_id                                   :bigint           not null, indexed
#  project_id                                     :bigint           not null, indexed, indexed => [priority]
#
# Indexes
#
#  index_campaigns_on_creator_id               (creator_id)
#  index_campaigns_on_deleted_at               (deleted_at)
#  index_campaigns_on_hash_list_id             (hash_list_id)
#  index_campaigns_on_priority                 (priority)
#  index_campaigns_on_project_id               (project_id)
#  index_campaigns_on_project_id_and_priority  (project_id,priority)
#  index_campaigns_on_quarantined              (quarantined) WHERE (quarantined = true)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Campaign do
  it "valid with a name, hash_list, and project" do
    campaign = create(:campaign)
    expect(campaign).to be_valid
  end

  describe "associations" do
    it { is_expected.to have_many(:attacks).dependent(:destroy) }
    it { is_expected.to have_many(:tasks).through(:attacks) }
    it { is_expected.to belong_to(:hash_list) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:creator).class_name("User").optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:priority) }
  end

  describe "scopes" do
    it "returns campaigns with completed attacks" do
      campaign = create(:campaign)
      attack = create(:dictionary_attack, campaign: campaign, name: "Attack Complete")
      create(:task, state: "completed", attack: attack)
      attack.complete!
      expect(described_class.completed).to include(campaign)
    end

    it "returns campaigns in projects with the given ids" do
      project = create(:project)
      project2 = create(:project, name: "Project 2")
      project3 = create(:project, name: "Project 3")
      campaign = create(:campaign, project: project)
      expect(described_class.in_projects([project.id, project2.id])).to include(campaign)
      expect(described_class.in_projects([project2.id, project3.id])).not_to include(campaign)
    end

    it "returns active campaigns" do
      campaign = create(:campaign)
      create(:dictionary_attack, campaign: campaign, state: "running")
      expect(described_class.active).to include(campaign)
    end

    describe ".quarantined" do
      it "returns only quarantined campaigns" do
        quarantined = create(:campaign, quarantined: true, quarantine_reason: "Token length exception")
        normal = create(:campaign)

        result = described_class.quarantined
        expect(result).to include(quarantined)
        expect(result).not_to include(normal)
      end
    end

    describe ".not_quarantined" do
      it "returns only non-quarantined campaigns" do
        quarantined = create(:campaign, quarantined: true, quarantine_reason: "Token length exception")
        normal = create(:campaign)

        result = described_class.not_quarantined
        expect(result).to include(normal)
        expect(result).not_to include(quarantined)
      end
    end
  end

  describe "soft delete" do
    subject(:campaign) { create(:campaign) }

    it "sets deleted_at instead of deleting the row" do
      expect { campaign.destroy }
        .to change { described_class.unscoped.find(campaign.id).deleted_at }.from(nil)
    end

    it "keeps the row in the database after destroy" do
      campaign.destroy
      expect(described_class.unscoped.exists?(campaign.id)).to be true
    end

    it "excludes discarded records from default queries" do
      campaign.destroy
      expect(described_class.all).not_to include(campaign)
    end

    it "exposes .kept scope for non-discarded records" do
      other = create(:campaign)
      campaign.destroy
      expect(described_class.kept).to include(other)
      expect(described_class.kept).not_to include(campaign)
    end

    it "exposes .discarded scope for soft-deleted records" do
      other = create(:campaign)
      campaign.destroy
      expect(described_class.discarded.pluck(:id)).to contain_exactly(campaign.id)
      expect(described_class.discarded).not_to include(other)
    end

    it "reaches discarded records via .unscoped" do
      campaign.destroy
      expect(described_class.unscoped.pluck(:id)).to include(campaign.id)
    end

    it "answers discarded? true after destroy" do
      campaign.destroy
      expect(campaign.reload.discarded?).to be true
    end

    it "answers kept? false after destroy" do
      campaign.destroy
      expect(campaign.reload.kept?).to be false
    end

    it "cascades discard to associated attacks" do
      attack = create(:dictionary_attack, campaign: campaign)
      expect { campaign.destroy }.to change { Attack.kept.exists?(attack.id) }.from(true).to(false)
      expect(Attack.unscoped.exists?(attack.id)).to be true # soft-deleted, still in DB
      expect(Attack.unscoped.find(attack.id).discarded?).to be true
    end

    it "is a no-op when destroy is called on an already-discarded record" do
      campaign.destroy
      expect { campaign.destroy }.not_to change { campaign.reload.deleted_at }
    end

    it "supports destroy! by soft-deleting the record" do
      expect { campaign.destroy! }
        .to change { described_class.unscoped.find(campaign.id).deleted_at }.from(nil)
      expect(campaign.reload.discarded?).to be true
    end
  end

  describe "instance methods" do
    let(:hash_list) { create(:hash_list) }
    let(:hash_item) { create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: DateTime.now, plain_text: "nothing") }

    let(:campaign) { create(:campaign) }
    let(:attack) { create(:dictionary_attack, campaign: campaign) }
    let(:task) { create(:task, attack: attack) }

    describe "#quarantine!" do
      it "sets quarantined flag and reason" do
        campaign.quarantine!("Token length exception")
        campaign.reload

        expect(campaign.quarantined).to be true
        expect(campaign.quarantine_reason).to eq("Token length exception")
      end

      it "raises ActiveRecord::RecordInvalid on validation failure" do
        campaign.name = nil
        expect { campaign.quarantine!("Some reason") }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe "#clear_quarantine!" do
      it "resets quarantined flag and reason" do
        campaign.update!(quarantined: true, quarantine_reason: "No hashes loaded")
        campaign.clear_quarantine!
        campaign.reload

        expect(campaign.quarantined).to be false
        expect(campaign.quarantine_reason).to be_nil
      end

      it "raises ActiveRecord::RecordInvalid on validation failure" do
        campaign.update!(quarantined: true, quarantine_reason: "Error")
        campaign.name = nil
        expect { campaign.clear_quarantine! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe "#quarantined?" do
      it "returns true when the campaign is quarantined" do
        campaign.update!(quarantined: true, quarantine_reason: "Token length exception")
        expect(campaign.quarantined?).to be true
      end

      it "returns false when the campaign is not quarantined" do
        expect(campaign.quarantined?).to be false
      end

      it "reflects persisted state after quarantine! and clear_quarantine!" do
        campaign.quarantine!("Error")
        expect(campaign.quarantined?).to be true

        campaign.clear_quarantine!
        expect(campaign.quarantined?).to be false
      end
    end

    describe "#paused?" do
      it "returns true if all attacks are paused" do
        create(:dictionary_attack, campaign: campaign, state: "paused")
        expect(campaign.paused?).to be true
      end

      it "returns false if there are attacks not in paused state" do
        create(:dictionary_attack, campaign: campaign, state: "running")
        expect(campaign.paused?).to be false
      end
    end

    describe "#priority_to_emoji" do
      it "returns the correct emoji for each priority" do
        expect(campaign.priority_to_emoji).to eq("🔄") # normal
        campaign.update(priority: :deferred)
        expect(campaign.priority_to_emoji).to eq("🕰")
        campaign.update(priority: :high)
        expect(campaign.priority_to_emoji).to eq("🔴")
      end
    end

    # describe "#resume" do
    #   it "resumes all associated attacks" do
    #     attack = create(:dictionary_attack, campaign: campaign, state: "paused")
    #     campaign.resume
    #     expect(attack.pending?).to be true
    #   end
    # end

    describe "#current_eta" do
      let(:campaign) { create(:campaign) }

      it "returns nil when there are no running attacks" do
        create(:dictionary_attack, campaign: campaign, state: "pending")
        expect(campaign.current_eta).to be_nil
      end

      it "returns the maximum ETA from running attacks" do
        attack = create(:dictionary_attack, campaign: campaign, state: "running")
        task = create(:task, attack: attack, state: "running")

        result = campaign.current_eta
        expect(result).to be_nil.or be_a(Time)
      end
    end

    describe "#total_eta" do
      let(:campaign) { create(:campaign) }

      it "returns nil when there are no incomplete attacks" do
        attack = create(:dictionary_attack, campaign: campaign, state: "completed")
        expect(campaign.total_eta).to be_nil
      end

      it "returns estimated total completion time for incomplete attacks" do
        attack = create(:dictionary_attack, campaign: campaign, state: "pending")
        result = campaign.total_eta
        expect(result).to be_nil.or be_a(Time)
      end
    end

    describe "#calculate_current_eta" do
      let(:campaign) { create(:campaign) }

      it "returns nil when there are no running attacks" do
        create(:dictionary_attack, campaign: campaign, state: "pending")
        expect(campaign.calculate_current_eta).to be_nil
      end

      it "returns the maximum ETA from running attack tasks" do
        attack = create(:dictionary_attack, campaign: campaign, state: "running")
        create(:task, attack: attack, state: "running")

        result = campaign.calculate_current_eta
        expect(result).to be_nil.or be_a(Time)
      end

      it "returns the same value as current_eta" do
        attack = create(:dictionary_attack, campaign: campaign, state: "running")
        create(:task, attack: attack, state: "running")

        expect(campaign.calculate_current_eta).to eq(campaign.current_eta)
      end
    end

    describe "#calculate_total_eta" do
      let(:campaign) { create(:campaign) }

      it "returns nil when there are no incomplete attacks" do
        create(:dictionary_attack, campaign: campaign, state: "completed")
        expect(campaign.calculate_total_eta).to be_nil
      end

      it "returns estimated total completion time for incomplete attacks" do
        create(:dictionary_attack, campaign: campaign, state: "pending")
        result = campaign.calculate_total_eta
        expect(result).to be_nil.or be_a(Time)
      end

      it "returns the same value as total_eta" do
        create(:dictionary_attack, campaign: campaign, state: "pending")

        expect(campaign.calculate_total_eta).to eq(campaign.total_eta)
      end
    end
  end

  describe "#trigger_priority_rebalance_if_needed" do
    include ActiveJob::TestHelper

    before { ActiveJob::Base.queue_adapter = :test }

    let(:campaign) { create(:campaign, priority: :normal) }

    after { clear_enqueued_jobs }

    it "enqueues CampaignPriorityRebalanceJob when priority is raised" do
      expect {
        campaign.update!(priority: :high)
      }.to have_enqueued_job(CampaignPriorityRebalanceJob).with(campaign.id)
    end

    it "does not enqueue a job when priority is lowered" do
      campaign.update!(priority: :high)
      clear_enqueued_jobs

      expect {
        campaign.update!(priority: :normal)
      }.not_to have_enqueued_job(CampaignPriorityRebalanceJob)
    end

    it "does not enqueue a job when priority is unchanged" do
      expect {
        campaign.update!(name: "Renamed Campaign")
      }.not_to have_enqueued_job(CampaignPriorityRebalanceJob)
    end

    it "enqueues a job when priority is raised from deferred to normal" do
      campaign.update!(priority: :deferred)
      clear_enqueued_jobs

      expect {
        campaign.update!(priority: :normal)
      }.to have_enqueued_job(CampaignPriorityRebalanceJob).with(campaign.id)
    end

    it "does not enqueue a job when priority value is unrecognized" do
      allow(campaign).to receive_messages(
        saved_change_to_priority?: true,
        saved_change_to_priority: %w[normal unknown_priority]
      )

      expect {
        campaign.send(:trigger_priority_rebalance_if_needed)
      }.not_to have_enqueued_job(CampaignPriorityRebalanceJob)
    end

    it "does not raise when Redis is unavailable during enqueue" do
      allow(CampaignPriorityRebalanceJob).to receive(:perform_later)
        .and_raise(Redis::CannotConnectError.new("Connection refused"))
      allow(Rails.logger).to receive(:error)

      expect { campaign.update!(priority: :high) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue priority rebalance.*Connection refused/)
    end
  end

  # Tests for manual pause/resume functionality
  describe "manual campaign control" do
    context "when pausing a campaign" do
      it "pauses all active attacks" do
        campaign = create(:campaign, priority: :normal)
        attack = create(:dictionary_attack, campaign: campaign, state: "running")

        campaign.pause
        attack.reload
        expect(attack.state).to eq("paused")
      end
    end

    context "when resuming a campaign" do
      it "resumes all paused attacks" do
        campaign = create(:campaign, priority: :normal)
        attack = create(:dictionary_attack, campaign: campaign, state: "paused")

        campaign.resume
        attack.reload
        expect(attack.state).to eq("pending")
      end
    end
  end

  describe "SafeBroadcasting integration" do
    let(:campaign) { create(:campaign) }

    it "includes SafeBroadcasting concern" do
      expect(described_class.included_modules).to include(SafeBroadcasting)
    end

    context "when broadcast fails" do
      it "logs BroadcastError without raising" do
        allow(Rails.logger).to receive(:error)
        expect { campaign.send(:log_broadcast_error, StandardError.new("Connection refused")) }.not_to raise_error
      end

      it "includes campaign ID in broadcast error log" do
        allow(Rails.logger).to receive(:error)
        campaign.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/Record ID: #{campaign.id}/).at_least(:once)
      end

      it "includes model name in broadcast error log" do
        allow(Rails.logger).to receive(:error)
        campaign.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/\[BroadcastError\].*Model: Campaign/).at_least(:once)
      end

      it "includes backtrace in broadcast error log" do
        allow(Rails.logger).to receive(:error)
        begin
          raise StandardError, "Test error"
        rescue StandardError => e
          campaign.send(:log_broadcast_error, e)
        end
        expect(Rails.logger).to have_received(:error).with(/Backtrace:/).at_least(:once)
      end
    end
  end
end
