# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Tasks" do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }
  let!(:agent) { create(:agent, projects: [project]) }
  let!(:campaign) { create(:campaign, project: project) }
  let!(:attack) { create(:dictionary_attack, campaign: campaign) }
  let!(:task) { create(:task, attack: attack, agent: agent) }

  describe "GET /show" do
    context "when user is not logged in" do
      it "redirects to login page" do
        expect(get(task_path(task))).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        get task_path(task)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get task_path(task)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end

    context "when an admin user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get task_path(task)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end

    context "when task does not exist" do
      it "returns http not found" do
        sign_in(project_user)
        get task_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
