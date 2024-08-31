# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Agents", type: :request do
  let!(:first_project) { create(:project) }
  let!(:second_project) { create(:project) }
  let!(:admin_user) { create(:user, role: :admin) }
  let!(:first_regular_user) { create(:user, role: :basic, projects: [first_project]) }
  let!(:second_regular_user) { create(:user, role: :basic, projects: [second_project]) }
  let!(:first_agent) { create(:agent, user: first_regular_user, projects: [first_project]) }
  let!(:second_agent) { create(:agent, user: second_regular_user, projects: [second_project]) }

  let!(:third_regular_user) {
    user = create(:user, role: :basic, projects: [first_project, second_project])
    user.project_users.find_by(project: first_project).update(role: :admin)
    user.save!
    user
  }

  describe "GET /index" do
    it "returns http success" do
      sign_in first_regular_user
      get agents_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end

    it "redirects to login page if not logged in" do
      get agents_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /:id" do
    context "when a non-logged in user tries to access an agent" do
      it "redirects to login page" do
        get agent_path(first_agent)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-admin user tries to access their own agent" do
      it "returns http success" do
        sign_in first_regular_user
        get agent_path(first_agent)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end

    context "when a non-admin user tries to access another user's agent" do
      it "returns http unauthorized" do
        sign_in first_regular_user
        get agent_path(second_agent)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when an admin user tries to access another user's agent" do
      it "returns http success" do
        sign_in admin_user
        get agent_path(first_agent)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end
  end

  describe "GET /new" do
    context "when a non-logged in user tries to access the new agent page" do
      it "redirects to login page" do
        get new_agent_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-admin user tries to access the new agent page" do
      it "returns http unauthorized" do
        sign_in first_regular_user
        get new_agent_path
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when an admin user tries to access the new agent page" do
      it "returns http success" do
        sign_in admin_user
        get new_agent_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /edit" do
    context "when a non-logged in user tries to access the edit agent page" do
      it "redirects to login page" do
        get edit_agent_path(first_agent)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-admin user tries to edit their own agent" do
      it "returns http success" do
        sign_in first_regular_user
        get edit_agent_path(first_agent)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end
    end

    context "when a non-admin user tries to edit another user's agent in a different project" do
      it "returns http unauthorized" do
        sign_in first_regular_user
        get edit_agent_path(second_agent)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when a non-admin user tries to edit another user's agent in the same project" do
      it "returns http unauthorized" do
        sign_in third_regular_user
        get edit_agent_path(second_agent)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when an admin user tries to edit another user's agent" do
      it "returns http success" do
        sign_in admin_user
        get edit_agent_path(first_agent)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end
    end
  end
end
