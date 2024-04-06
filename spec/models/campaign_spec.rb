# frozen_string_literal: true

# == Schema Information
#
# Table name: campaigns
#
#  id           :bigint           not null, primary key
#  name         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  hash_list_id :bigint           not null, indexed
#  project_id   :bigint           indexed
#
# Indexes
#
#  index_campaigns_on_hash_list_id  (hash_list_id)
#  index_campaigns_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_list_id => hash_lists.id)
#  fk_rails_...  (project_id => projects.id)
#
require 'rails_helper'

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
  end

  describe "scopes" do
    it "returns campaigns with completed attacks" do
      campaign = create(:campaign)
      attack = create(:attack, campaign: campaign, name: 'Attack Complete')
      attack.tasks << create(:task, state: "completed")
      attack.complete!
      expect(described_class.completed).to include(campaign)
    end

    it "returns campaigns in projects with the given ids" do
      project = create(:project)
      project2 = create(:project, name: "Project 2")
      campaign = create(:campaign, project: project)
      expect(described_class.in_projects([project.id, project2.id])).to include(campaign)
    end
  end

  # describe "audit" do
  #   let(:campaign) { create(:campaign) }
  #
  #   it "is audited" do
  #     expect(campaign.audits.count).to eq(1)
  #     campaign.update(name: "New Name")
  #     expect(campaign.audits.count).to eq(2)
  #   end
  # end
end
