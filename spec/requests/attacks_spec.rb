# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Attacks", type: :request do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }

  let(:campaign) { create(:campaign, project: project) }
  let(:attack) { create(:dictionary_attack, campaign: campaign) }

  describe "GET /new" do
    context "when user is not logged in" do
      it { expect(get(new_campaign_attack_path(campaign))).to redirect_to(new_user_session_path) }
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        get new_campaign_attack_path(campaign)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get new_campaign_attack_path(campaign)
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get new_campaign_attack_path(campaign)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /edit" do
    context "when user is not logged in" do
      it { expect(get(edit_campaign_attack_path(campaign, attack))).to redirect_to(new_user_session_path) }
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in non_project_user
        get edit_campaign_attack_path(campaign, attack)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in admin
        get edit_campaign_attack_path(campaign, attack)
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in project_user
        get edit_campaign_attack_path(campaign, attack)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /show" do
    context "when user is not logged in" do
      it { expect(get(campaign_attack_path(campaign, attack))).to redirect_to(new_user_session_path) }
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in non_project_user
        get campaign_attack_path(campaign, attack)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in admin
        get campaign_attack_path(campaign, attack)
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in project_user
        get campaign_attack_path(campaign, attack)
        expect(response).to have_http_status(:success)
      end
    end
  end
end
