# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "HashLists" do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }

  let(:hash_list) { create(:hash_list, project: project, processed: true) }

  describe "GET /index" do
    context "when user is not logged in" do
      it { expect(get(hash_lists_path)).to redirect_to(new_user_session_path) }
    end

    context "when admin user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get hash_lists_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get hash_lists_path
        expect(response).to have_http_status(:success)
      end
    end
  end

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

  describe "PATCH /update" do
    before { allow(ProcessHashListJob).to receive(:perform_now) }

    let(:new_file) { fixture_file_upload("spec/fixtures/hash_lists/example_hashes.txt", "text/plain") }

    context "when user is not logged in" do
      it "redirects to login page" do
        patch hash_list_path(hash_list), params: { hash_list: { file: new_file } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in non_project_user
        patch hash_list_path(hash_list), params: { hash_list: { file: new_file } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin user is logged in" do
      before { sign_in admin }

      it "updates the hash list and reprocesses the file" do
        hash_list.update(processed: true)
        expect {
          patch hash_list_path(hash_list), params: { hash_list: { file: new_file } }
          hash_list.reload
        }.to change(hash_list, :processed).from(true).to(false)

        expect(response).to redirect_to(hash_list_path(hash_list))
        expect(flash[:notice]).to eq("Hash list was successfully updated.")
      end
    end

    context "when a project user is logged in" do
      before { sign_in project_user }

      it "updates the hash list and reprocesses the file" do
        hash_list.update(processed: true)
        expect {
          patch hash_list_path(hash_list), params: { hash_list: { file: new_file } }
          hash_list.reload
        }.to change(hash_list, :processed).from(true).to(false)

        expect(response).to redirect_to(hash_list_path(hash_list))
        expect(flash[:notice]).to eq("Hash list was successfully updated.")
      end
    end
  end
end
