# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaskLists", type: :request do
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
  end
end
