# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Projects", type: :request do
  let(:project) { create(:project) }
  let(:user) { create(:user, projects: [project]) }
  let(:project_user) { build(:project_user, project: project, user: user, role: :editor) }

  describe "GET /new" do
    it "returns http success" do
      sign_in user
      get new_project_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
    end
  end

  describe "GET /edit" do
    context "when user is a project member" do
      it "returns http success" do
        # I have no idea why this is necessary, but it won't save the role if I just put it in the build method
        project_user.save!

        sign_in user
        get edit_project_path(project)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end
    end

    context "when user is not a project member" do
      let(:other_user) { create(:user) }

      it "returns http unauthorized" do
        sign_in other_user
        get edit_project_path(project)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
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
    it "returns http success" do
      sign_in user
      get project_path(project)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
    end
  end
end
