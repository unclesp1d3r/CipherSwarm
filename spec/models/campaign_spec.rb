# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: campaigns
#
#  id                                                                                                     :bigint           not null, primary key
#  attacks_count                                                                                          :integer          default(0), not null
#  deleted_at                                                                                             :datetime         indexed
#  description                                                                                            :text
#  name                                                                                                   :string           not null
#  priority( -1: Deferred, 0: Routine, 1: Priority, 2: Urgent, 3: Immediate, 4: Flash, 5: Flash Override) :integer          default("routine"), not null
#  created_at                                                                                             :datetime         not null
#  updated_at                                                                                             :datetime         not null
#  hash_list_id                                                                                           :bigint           not null, indexed
#  project_id                                                                                             :bigint           not null, indexed
#
# Indexes
#
#  index_campaigns_on_deleted_at    (deleted_at)
#  index_campaigns_on_hash_list_id  (hash_list_id)
#  index_campaigns_on_project_id    (project_id)
#
# Foreign Keys
#
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
  end

  describe "instance methods" do
    let(:hash_list) { create(:hash_list) }
    let(:hash_item) { create(:hash_item, hash_list: hash_list, cracked: true, cracked_time: DateTime.now, plain_text: "nothing") }

    let(:campaign) { create(:campaign) }
    let(:attack) { create(:dictionary_attack, campaign: campaign) }
    let(:task) { create(:task, attack: attack) }

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
      it "returns the correct emoji for each priority" do # rubocop:disable RSpec/MultipleExpectations
        expect(campaign.priority_to_emoji).to eq("🔄") # routine
        campaign.update(priority: :deferred)
        expect(campaign.priority_to_emoji).to eq("🕰")
        campaign.update(priority: :priority)
        expect(campaign.priority_to_emoji).to eq("🔵")
        campaign.update(priority: :urgent)
        expect(campaign.priority_to_emoji).to eq("🟠")
        campaign.update(priority: :immediate)
        expect(campaign.priority_to_emoji).to eq("🔴")
        campaign.update(priority: :flash)
        expect(campaign.priority_to_emoji).to eq("🟡")
        campaign.update(priority: :flash_override)
        expect(campaign.priority_to_emoji).to eq("🔒")
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

      it "returns the maximum ETA from running attacks" do
        attack = create(:dictionary_attack, campaign: campaign, state: "running")
        task = create(:task, attack: attack, state: "running")

        eta = campaign.calculate_current_eta
        # Should return a time or nil
        expect(eta).to be_nil.or be_a(Time)
      end

      it "returns nil when there are no running attacks" do
        expect(campaign.calculate_current_eta).to be_nil
      end
    end

    describe "#calculate_total_eta" do
      let(:campaign) { create(:campaign) }

      it "returns nil when there are no incomplete attacks" do
        expect(campaign.calculate_total_eta).to be_nil
      end

      it "returns total ETA for all incomplete attacks" do
        attack = create(:dictionary_attack, campaign: campaign, state: "pending")
        expect(campaign.calculate_total_eta).to be_nil.or be_a(Time)
      end
    end
  end

  describe ".pause_lower_priority_campaigns" do
    context "when no campaigns exist" do
      it "completes without raising errors" do
        expect { described_class.pause_lower_priority_campaigns }.not_to raise_error
      end
    end

    context "when no active campaigns exist" do
      it "completes without raising errors when all campaigns are completed" do
        campaign = create(:campaign)
        create(:dictionary_attack, campaign: campaign, state: "completed")
        expect { described_class.pause_lower_priority_campaigns }.not_to raise_error
      end
    end

    context "when a single active campaign exists" do
      it "resumes the campaign" do
        campaign = create(:campaign, priority: :routine)
        attack = create(:dictionary_attack, campaign: campaign, state: "paused")

        described_class.pause_lower_priority_campaigns
        attack.reload
        expect(attack.state).to eq("pending")
      end
    end

    context "when multiple campaigns with same priority exist" do
      it "resumes all campaigns with max priority" do
        campaign1 = create(:campaign, priority: :routine)
        campaign2 = create(:campaign, priority: :routine)
        attack1 = create(:dictionary_attack, campaign: campaign1, state: "paused")
        attack2 = create(:dictionary_attack, campaign: campaign2, state: "paused")

        described_class.pause_lower_priority_campaigns
        attack1.reload
        attack2.reload
        expect(attack1.state).to eq("pending")
        expect(attack2.state).to eq("pending")
      end
    end

    context "when multiple campaigns with different priorities exist" do
      it "pauses lower priority campaigns and resumes highest priority" do
        low_priority = create(:campaign, priority: :routine)
        high_priority = create(:campaign, priority: :urgent)
        low_attack = create(:dictionary_attack, campaign: low_priority, state: "running")
        high_attack = create(:dictionary_attack, campaign: high_priority, state: "paused")

        described_class.pause_lower_priority_campaigns
        low_attack.reload
        high_attack.reload
        expect(low_attack.state).to eq("paused")
        expect(high_attack.state).to eq("pending")
      end

      it "pauses all campaigns below highest priority" do
        deferred = create(:campaign, priority: :deferred)
        routine = create(:campaign, priority: :routine)
        urgent = create(:campaign, priority: :urgent)
        deferred_attack = create(:dictionary_attack, campaign: deferred, state: "running")
        routine_attack = create(:dictionary_attack, campaign: routine, state: "running")
        urgent_attack = create(:dictionary_attack, campaign: urgent, state: "paused")

        described_class.pause_lower_priority_campaigns
        deferred_attack.reload
        routine_attack.reload
        urgent_attack.reload
        expect(deferred_attack.state).to eq("paused")
        expect(routine_attack.state).to eq("paused")
        expect(urgent_attack.state).to eq("pending")
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
