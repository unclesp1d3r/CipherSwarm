# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe CampaignsHelper do
  let(:project) { create(:project) }
  let(:hash_list) { create(:hash_list, project: project) }
  let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
  let(:user) { create(:user) }

  describe "#available_priorities_for" do
    context "when user is a global admin" do
      it "returns all priorities including high" do
        admin_user = create(:admin)

        result = helper.available_priorities_for(campaign, admin_user)

        expect(result).to eq(%i[deferred normal high])
      end
    end

    context "when user is a project admin" do
      it "returns all priorities including high" do
        project.project_users.create!(user: user, role: :admin)

        result = helper.available_priorities_for(campaign, user)

        expect(result).to eq(%i[deferred normal high])
      end
    end

    context "when user is a project owner" do
      it "returns all priorities including high" do
        project.project_users.create!(user: user, role: :owner)

        result = helper.available_priorities_for(campaign, user)

        expect(result).to eq(%i[deferred normal high])
      end
    end

    context "when user is a regular project member" do
      it "returns only deferred and normal priorities" do
        project.project_users.create!(user: user, role: :viewer)

        result = helper.available_priorities_for(campaign, user)

        expect(result).to eq(%i[deferred normal])
      end
    end

    context "when campaign does not have a project_id" do
      it "uses hash_list project_id if available" do
        campaign_without_project = build(:campaign, project: nil, hash_list: hash_list)
        project.project_users.create!(user: user, role: :admin)

        result = helper.available_priorities_for(campaign_without_project, user)

        expect(result).to eq(%i[deferred normal high])
      end

      it "returns only base priorities if no project can be determined" do
        campaign_without_project = build(:campaign, project: nil, hash_list: nil)

        result = helper.available_priorities_for(campaign_without_project, user)

        expect(result).to eq(%i[deferred normal])
      end
    end

    context "when user has no association with the project" do
      it "returns only deferred and normal priorities" do
        result = helper.available_priorities_for(campaign, user)

        expect(result).to eq(%i[deferred normal])
      end
    end
  end
end
