# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Projects", type: :request do
  let(:project) { create(:project) }
  let(:user) { create(:user, projects: [project]) }

  describe "GET /new" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get new_project_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is a regular user" do
      it "returns http unauthorized" do
        sign_in user
        get new_project_path
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when user is an admin" do
      let(:admin) { create(:user, role: :admin) }

      it "returns http success" do
        sign_in admin
        get new_project_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /edit" do
    context "when user is not a project member" do
      let(:other_user) { create(:user) }

      it "returns http unauthorized" do
        sign_in other_user
        get edit_project_path(project)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when user is a project viewer" do
      it "returns http unauthorized" do
        user.project_users.where(project: project).update(role: :viewer)

        sign_in user
        get edit_project_path(project)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user is a project editor" do
      it "returns http unauthorized" do
        user.project_users.where(project: project).update(role: :editor)

        sign_in user
        get edit_project_path(project)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user is a project contributor" do
      it "returns http unauthorized" do
        user.project_users.where(project: project).update(role: :contributor)

        sign_in user
        get edit_project_path(project)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user is a project admin" do
      it "returns http success" do
        user.project_users.where(project: project).update(role: :admin)

        sign_in user
        get edit_project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end
    end

    context "when user is a project owner" do
      it "returns http success" do
        user.project_users.where(project: project).update(role: :owner)

        sign_in user
        get edit_project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end
    end

    context "when user is an admin" do
      let(:admin) { create(:user, role: :admin) }

      it "returns http success" do
        sign_in admin
        get edit_project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe "GET /show" do
    context "when user is not a project member" do
      let(:other_user) { create(:user) }

      it "returns http unauthorized" do
        sign_in other_user
        get project_path(project)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when user is a project member" do
      it "returns http success" do
        sign_in user
        get project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end
  end
end
