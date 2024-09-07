# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Campaigns", type: :request do
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
end
