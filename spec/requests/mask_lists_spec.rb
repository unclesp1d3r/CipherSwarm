# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "MaskLists" do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }

  let!(:sensitive_mask_list) { create(:mask_list, projects: [project], sensitive: true) }
  let!(:public_mask_list) { create(:mask_list, projects: [], sensitive: false) }

  describe "GET /index" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get mask_lists_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when admin user is signed in" do
      it "returns http success" do
        sign_in admin
        get mask_lists_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is signed in" do
      it "returns http success" do
        sign_in project_user
        get mask_lists_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /new" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get new_mask_list_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when an admin user is signed in" do
      it "returns http success" do
        sign_in admin
        get new_mask_list_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is signed in" do
      it "returns http success" do
        sign_in project_user
        get new_mask_list_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /edit" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get edit_mask_list_path(public_mask_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when mask list is sensitive" do
      context "when an admin user is signed in" do
        it "returns http success" do
          sign_in admin
          get edit_mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when a non-project user is signed in" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get edit_mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when a project user is signed in" do
        it "returns http success" do
          sign_in project_user
          get edit_mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when mask list is not sensitive" do
      context "when an admin user is signed in" do
        it "returns http success" do
          sign_in admin
          get edit_mask_list_path(public_mask_list)
          expect(response).to have_http_status(:success)
        end

        context "when a non-project user is signed in" do
          it "returns http unauthorized" do
            sign_in non_project_user
            get edit_mask_list_path(public_mask_list)
            expect(response).to have_http_status(:unauthorized)
          end
        end

        context "when a project user is signed in" do
          it "returns http unauthorized" do
            sign_in project_user
            get edit_mask_list_path(public_mask_list)
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end

  describe "GET /show" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get mask_list_path(public_mask_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the mask list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the mask list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get mask_list_path(public_mask_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the mask list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the mask list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get mask_list_path(public_mask_list)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /view_file" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get view_file_mask_list_path(public_mask_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the mask list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get view_file_mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the mask list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get view_file_mask_list_path(public_mask_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the mask list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the mask list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_mask_list_path(public_mask_list)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /view_file_content" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get view_file_content_mask_list_path(public_mask_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the mask list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get view_file_content_mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the mask list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get view_file_content_mask_list_path(public_mask_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the mask list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_content_mask_list_path(sensitive_mask_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the mask list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_content_mask_list_path(public_mask_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    describe "POST /create" do
      let(:file) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/mask_lists/rockyou-1-60.hcmask")) }
      let(:params) { { mask_list: { name: "Test Mask List", description: "Test Description", file: file } } }
      let(:private_params) { { mask_list: { name: "Test Mask List", description: "Test Description", file: file, project_ids: [project.id] } } }

      context "when user is not signed in" do
        it "redirects to sign in page" do
          post mask_lists_path, params: params
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when an admin user is signed in" do
        it "creates a new mask list" do
          sign_in admin
          post mask_lists_path, params: params
          expect(response).to redirect_to(mask_list_path(MaskList.last))
          expect(flash[:notice]).to eq("Mask list was successfully created.")
        end

        it "creates a new sensitive mask list" do
          sign_in admin
          post mask_lists_path, params: private_params
          expect(response).to redirect_to(mask_list_path(MaskList.last))
          expect(flash[:notice]).to eq("Mask list was successfully created.")
        end
      end

      context "when a non-project user is signed in" do
        it "creates a new public mask list" do
          sign_in non_project_user
          post mask_lists_path, params: params
          expect(response).to redirect_to(mask_list_path(MaskList.last))
          expect(flash[:notice]).to eq("Mask list was successfully created.")
        end

        it "fails to create a new sensitive mask list" do
          sign_in non_project_user
          post mask_lists_path, params: private_params
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when a project user is signed in" do
        it "creates a new public mask list" do
          sign_in project_user
          post mask_lists_path, params: params
          expect(response).to redirect_to(mask_list_path(MaskList.last))
          expect(flash[:notice]).to eq("Mask list was successfully created.")
        end

        it "creates a new sensitive mask list" do
          sign_in project_user
          post mask_lists_path, params: private_params
          expect(response).to redirect_to(mask_list_path(MaskList.last))
          expect(flash[:notice]).to eq("Mask list was successfully created.")
        end

        it "fails to create mask list with unauthorized project IDs" do
          unauthorized_project = create(:project)
          params_with_unauthorized_project = {
            mask_list: {
              name: "Test Mask List",
              description: "Test Description",
              file: file,
              project_ids: [unauthorized_project.id]
            }
          }

          sign_in project_user
          post mask_lists_path, params: params_with_unauthorized_project
          expect(response).to have_http_status(:forbidden)
          expect(flash[:error]).to include("You don't have permission")
        end

        it "fails gracefully with non-existent project IDs" do
          params_with_invalid_project = {
            mask_list: {
              name: "Test Mask List",
              description: "Test Description",
              file: file,
              project_ids: [99999]
            }
          }

          sign_in project_user
          post mask_lists_path, params: params_with_invalid_project
          expect(response).to have_http_status(:not_found)
        end

        it "handles empty string in project_ids array" do
          params_with_empty_strings = {
            mask_list: {
              name: "Test Mask List",
              description: "Test Description",
              file: file,
              project_ids: [""]
            }
          }

          sign_in project_user
          post mask_lists_path, params: params_with_empty_strings
          expect(response).to redirect_to(mask_list_path(MaskList.last))
          expect(MaskList.last.projects).to be_empty
          expect(MaskList.last.sensitive).to be false
        end
      end
    end
  end
end
