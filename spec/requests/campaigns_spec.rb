# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Campaigns" do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }
  let!(:campaign) { create(:campaign) }

  describe "GET /index" do
    context "when user is not logged in" do
      it { expect(get(campaigns_path)).to redirect_to(new_user_session_path) }
    end

    context "when non-project user is logged in" do
      it "returns http success" do
        sign_in(non_project_user)
        get campaigns_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:index)
      end
    end

    context "when project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get campaigns_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "GET /new" do
    context "when user is not logged in" do
      it { expect(get(new_campaign_path)).to redirect_to(new_user_session_path) }
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get new_campaign_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:new)
      end
    end

    context "when project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get new_campaign_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /show" do
    context "when user is not logged in" do
      it { expect(get(campaign_path(campaign))).to redirect_to(new_user_session_path) }
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        get campaign_path(campaign)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get campaign_path(campaign)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end
  end

  describe "POST /create with priority authorization" do
    let!(:hash_list) { create(:hash_list, project: project) }

    context "when global admin creates campaign with high priority" do
      it "succeeds" do
        sign_in(admin)
        expect {
          post campaigns_path, params: {
            campaign: {
              name: "Admin Campaign",
              hash_list_id: hash_list.id,
              priority: "high"
            }
          }
        }.to change(Campaign, :count).by(1)
        # Extract campaign ID from redirect location
        campaign_id = response.location.match(%r{/campaigns/(\d+)})&.captures&.first
        new_campaign = Campaign.find(campaign_id)
        expect(response).to redirect_to(campaign_path(new_campaign))
        expect(new_campaign.priority).to eq("high")
      end
    end

    context "when project admin creates campaign with high priority" do
      it "succeeds" do
        project_admin = create(:user, projects: [project])
        create(:project_user, project: project, user: project_admin, role: :admin)
        sign_in(project_admin)
        expect {
          post campaigns_path, params: {
            campaign: {
              name: "Admin Campaign",
              hash_list_id: hash_list.id,
              priority: "high"
            }
          }
        }.to change(Campaign, :count).by(1)
        # Extract campaign ID from redirect location
        campaign_id = response.location.match(%r{/campaigns/(\d+)})&.captures&.first
        new_campaign = Campaign.find(campaign_id)
        expect(response).to redirect_to(campaign_path(new_campaign))
        expect(new_campaign.priority).to eq("high")
      end
    end

    context "when project owner creates campaign with high priority" do
      it "succeeds" do
        project_owner = create(:user, projects: [project])
        create(:project_user, project: project, user: project_owner, role: :owner)
        sign_in(project_owner)
        expect {
          post campaigns_path, params: {
            campaign: {
              name: "Owner Campaign",
              hash_list_id: hash_list.id,
              priority: "high"
            }
          }
        }.to change(Campaign, :count).by(1)
        # Extract campaign ID from redirect location
        campaign_id = response.location.match(%r{/campaigns/(\d+)})&.captures&.first
        new_campaign = Campaign.find(campaign_id)
        expect(response).to redirect_to(campaign_path(new_campaign))
        expect(new_campaign.priority).to eq("high")
      end
    end

    context "when regular project member attempts high priority" do
      it "fails with authorization error" do
        sign_in(project_user)
        campaigns_before = Campaign.count
        post campaigns_path, params: {
          campaign: {
            name: "Unauthorized Campaign",
            hash_list_id: hash_list.id,
            priority: "high"
          }
        }
        expect(Campaign.count).to eq(campaigns_before)
        expect(response).to redirect_to(campaigns_path)
        expect(flash[:alert]).to include("not authorized")
      end
    end

    context "when regular member creates campaign with normal priority" do
      it "succeeds" do
        sign_in(project_user)
        expect {
          post campaigns_path, params: {
            campaign: {
              name: "Normal Campaign",
              hash_list_id: hash_list.id,
              priority: "normal"
            }
          }
        }.to change(Campaign, :count).by(1)
        # Extract campaign ID from redirect location
        campaign_id = response.location.match(%r{/campaigns/(\d+)})&.captures&.first
        new_campaign = Campaign.find(campaign_id)
        expect(response).to redirect_to(campaign_path(new_campaign))
        expect(new_campaign.priority).to eq("normal")
      end
    end
  end

  describe "PATCH /update with priority authorization" do
    let!(:project_campaign) { create(:campaign, project: project, priority: :normal) }
    let!(:project_admin) { create(:user, projects: [project]) }

    before { create(:project_user, project: project, user: project_admin, role: :admin) }

    context "when project admin updates to high priority" do
      it "succeeds" do
        sign_in(project_admin)
        patch campaign_path(project_campaign), params: {
          campaign: { priority: "high" }
        }
        expect(response).to redirect_to(campaign_path(project_campaign))
        expect(project_campaign.reload.priority).to eq("high")
      end
    end

    context "when regular member attempts to update to high priority" do
      it "fails with authorization error" do
        sign_in(project_user)
        patch campaign_path(project_campaign), params: {
          campaign: { priority: "high" }
        }
        expect(response).to redirect_to(campaigns_path)
        expect(flash[:alert]).to include("not authorized")
        expect(project_campaign.reload.priority).to eq("normal")
      end
    end
  end
end
