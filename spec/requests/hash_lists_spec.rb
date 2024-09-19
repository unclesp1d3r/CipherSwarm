# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HashLists", type: :request do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }

  let(:hash_list) { create(:hash_list, project: project) }

  describe "GET /new" do
    context "when user is not logged in" do
      it { expect(get(new_hash_list_path)).to redirect_to(new_user_session_path) }
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get new_hash_list_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get new_hash_list_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /edit" do
    context "when user is not logged in" do
      it { expect(get(edit_hash_list_path(hash_list))).to redirect_to(new_user_session_path) }
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in non_project_user
        get edit_hash_list_path(hash_list)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in admin
        get edit_hash_list_path(hash_list)
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in project_user
        get edit_hash_list_path(hash_list)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /show" do
    context "when user is not logged in" do
      it { expect(get(hash_list_path(hash_list))).to redirect_to(new_user_session_path) }
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in non_project_user
        get hash_list_path(hash_list)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in admin
        get hash_list_path(hash_list)
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in project_user
        get hash_list_path(hash_list)
        expect(response).to have_http_status(:success)
      end
    end
  end
end
