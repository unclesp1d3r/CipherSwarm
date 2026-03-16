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
  let!(:campaign) { create(:campaign, project: project) }

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

    context "when filtering by quarantined" do
      let!(:quarantined_campaign) do
        create(:campaign, project: project, quarantined: true, quarantine_reason: "No hashes loaded")
      end

      it "returns only quarantined campaigns" do
        sign_in(admin)
        get campaigns_path, params: { filter: "quarantined" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(quarantined_campaign.name)
        expect(response.body).not_to include(campaign.name)
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
      it "returns http forbidden" do
        sign_in(non_project_user)
        get campaign_path(campaign)
        expect(response).to have_http_status(:forbidden)
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

    context "when campaign has failed attacks with errors" do
      let!(:agent) { create(:agent, projects: [project]) }
      let!(:failed_attack) do
        attack = create(:dictionary_attack, campaign: campaign)
        attack.run! if attack.can_run?
        attack.error! if attack.can_error?
        attack
      end
      let!(:task) { create(:task, attack: failed_attack, agent: agent) }

      before do
        create(:agent_error, agent: agent, task: task, severity: :critical)
      end

      it "returns http success and loads error map" do
        sign_in(project_user)
        get campaign_path(campaign)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end
  end

  describe "GET /error_log" do
    context "when user is not logged in" do
      it { expect(get(error_log_campaign_path(campaign))).to redirect_to(new_user_session_path) }
    end

    context "when a non-project user is logged in" do
      it "returns http forbidden" do
        sign_in(non_project_user)
        get error_log_campaign_path(campaign)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get error_log_campaign_path(campaign)
        expect(response).to have_http_status(:success)
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
        project_admin = create(:user)
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
        project_owner = create(:user)
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
        expect(response).to have_http_status(:forbidden)
        expect(response).to render_template("errors/not_authorized")
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

  describe "POST /toggle_paused" do
    context "when user is not logged in" do
      it "redirects to sign in" do
        post campaign_toggle_paused_path(campaign)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authorized user pauses a campaign" do
      before do
        create(:agent, projects: [project])
        create(:dictionary_attack, campaign: campaign, state: :running)
      end

      it "pauses the campaign and redirects to campaign page" do
        sign_in(admin)
        post campaign_toggle_paused_path(campaign)
        expect(response).to redirect_to(campaign_path(campaign))
      end
    end

    context "when authorized user resumes a paused campaign" do
      before do
        create(:agent, projects: [project])
        atk = create(:dictionary_attack, campaign: campaign)
        atk.run! if atk.can_run?
        atk.pause! if atk.can_pause?
      end

      it "resumes the campaign and redirects to campaign page" do
        sign_in(admin)
        expect(campaign.paused?).to be true
        post campaign_toggle_paused_path(campaign)
        expect(response).to redirect_to(campaign_path(campaign))
      end
    end

    context "when non-project user tries to toggle pause" do
      it "returns forbidden" do
        sign_in(non_project_user)
        post campaign_toggle_paused_path(campaign)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /update with priority authorization" do
    let!(:project_campaign) { create(:campaign, project: project, priority: :normal) }
    let!(:project_admin) { create(:user) }

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
        expect(response).to have_http_status(:forbidden)
        expect(response).to render_template("errors/not_authorized")
        expect(project_campaign.reload.priority).to eq("normal")
      end
    end
  end

  describe "POST /campaigns/:id/clear_quarantine" do
    let!(:quarantined_campaign) do
      create(:campaign, project: project, quarantined: true, quarantine_reason: "Token length exception")
    end

    context "when admin clears quarantine" do
      it "clears the quarantine and redirects" do
        sign_in(admin)
        post clear_quarantine_campaign_path(quarantined_campaign)
        expect(quarantined_campaign.reload).not_to be_quarantined
        expect(quarantined_campaign.quarantine_reason).to be_nil
        expect(response).to redirect_to(campaign_path(quarantined_campaign))
        expect(flash[:notice]).to eq("Campaign quarantine has been cleared.")
      end
    end

    context "when non-admin attempts to clear quarantine" do
      it "returns forbidden" do
        sign_in(project_user)
        post clear_quarantine_campaign_path(quarantined_campaign)
        expect(response).to have_http_status(:forbidden)
        expect(quarantined_campaign.reload).to be_quarantined
      end
    end
  end
end
