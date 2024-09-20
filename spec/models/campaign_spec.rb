# frozen_string_literal: true

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
  end
end
