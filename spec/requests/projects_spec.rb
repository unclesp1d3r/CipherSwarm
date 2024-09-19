# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Projects", type: :request do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }

  describe "GET /new" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get new_project_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is a regular user" do
      it "returns http unauthorized" do
        sign_in project_user
        get new_project_path
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when user is an admin" do
      it "returns http success" do
        sign_in admin
        get new_project_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /edit" do
    context "when user is an admin" do
      it "returns http success" do
        sign_in admin
        get edit_project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end
    end

    context "when user is not a project member" do
      it "returns http unauthorized" do
        sign_in non_project_user
        get edit_project_path(project)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when user is a project viewer" do
      it "returns http unauthorized" do
        sign_in project_user
        get edit_project_path(project)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /show" do
    context "when user is an admin" do
      it "returns http success" do
        sign_in admin
        get project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end

    context "when user is not a project member" do
      it "returns http unauthorized" do
        sign_in non_project_user
        get project_path(project)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when user is a project member" do
      it "returns http success" do
        sign_in project_user
        get project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end
  end
end
