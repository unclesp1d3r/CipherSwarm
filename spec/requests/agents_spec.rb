# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Agents", type: :request do
  let!(:first_project) { create(:project) }
  let!(:second_project) { create(:project) }
  let!(:admin_user) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:first_regular_user) { create(:user, projects: [first_project]) }
  let!(:second_regular_user) { create(:user, projects: [second_project]) }
  let!(:first_agent) { create(:agent, user: first_regular_user, projects: [first_project]) }
  let!(:second_agent) { create(:agent, user: second_regular_user, projects: [second_project]) }

  let!(:third_regular_user) {
    user = create(:user, role: :basic, projects: [first_project, second_project])
    user.add_role(:admin, first_project)
    user
  }

  describe "#index" do
    context "when a non-logged in user tries to access the agents index" do
      it "redirects to login page" do
        get agents_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-admin user tries to access the agents index" do
      it "returns http success" do
        sign_in first_regular_user
        get agents_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:index)
      end
    end

    context "when an admin user tries to access the agents index" do
      it "returns http success" do
        sign_in admin_user
        get agents_path
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "#show" do
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

  describe "#create" do
    let(:form_params) {
      {
        agent: {
          active: "true",
          name: "ebert",
          operating_system: "linux",
          user_id: admin_user.id
        }
      }
    }

    context "when user is not signed in" do
      it "redirects to login page" do
        post agents_path, params: form_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when use is not an admin" do
      it "returns http unauthorized" do
        sign_in first_regular_user
        post agents_path, params: form_params
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when user is an admin" do
      it "returns http success" do
        sign_in admin_user
        post agents_path, params: form_params
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to agent_path(Agent.last)
      end
    end
  end

  describe "#new" do
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

  describe "#edit" do
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

  describe "#update" do
    let(:first_agent_form_params) {
      {
        id: first_agent.id,
        agent: {
          name: "New Name",
          description: "New Description",
          project_ids: [first_project.id]
        }
      }
    }

    let(:second_agent_form_params) {
      {
        id: second_agent.id,
        agent: {
          name: "New Name",
          description: "New Description",
          project_ids: [second_project.id]
        }
      }
    }

    context "when a non-logged in user tries to access the edit agent page" do
      it "redirects to login page" do
        patch agent_path(first_agent), params: first_agent_form_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-admin user tries to edit their own agent" do
      it "returns http success" do
        sign_in first_regular_user
        patch agent_path(first_agent), params: first_agent_form_params
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(agent_path(first_agent))
      end
    end

    context "when a non-admin user tries to edit another user's agent in a different project" do
      it "returns http unauthorized" do
        sign_in first_regular_user
        patch agent_path(second_agent), params: second_agent_form_params
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when a non-admin user tries to edit another user's agent in the same project" do
      it "returns http unauthorized" do
        sign_in third_regular_user
        patch agent_path(second_agent), params: second_agent_form_params
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when an admin user tries to edit another user's agent" do
      it "returns http success" do
        sign_in admin_user
        patch agent_path(first_agent), params: first_agent_form_params
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(agent_path(first_agent))
      end
    end
  end
end
