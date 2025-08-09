# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "RuleLists" do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }

  let!(:sensitive_rule_list) { create(:rule_list, projects: [project], sensitive: true) }
  let!(:public_rule_list) { create(:rule_list, projects: [], sensitive: false) }

  describe "GET /index" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get rule_lists_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when admin user is signed in" do
      it "returns http success" do
        sign_in admin
        get rule_lists_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is signed in" do
      it "returns http success" do
        sign_in project_user
        get rule_lists_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /new" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get new_rule_list_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when an admin user is signed in" do
      it "returns http success" do
        sign_in admin
        get new_rule_list_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is signed in" do
      it "returns http success" do
        sign_in project_user
        get new_rule_list_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /edit" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get edit_rule_list_path(public_rule_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when rule list is sensitive" do
      context "when an admin user is signed in" do
        it "returns http success" do
          sign_in admin
          get edit_rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when a non-project user is signed in" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get edit_rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when a project user is signed in" do
        it "returns http success" do
          sign_in project_user
          get edit_rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when rule list is not sensitive" do
      context "when an admin user is signed in" do
        it "returns http success" do
          sign_in admin
          get edit_rule_list_path(public_rule_list)
          expect(response).to have_http_status(:success)
        end

        context "when a non-project user is signed in" do
          it "returns http unauthorized" do
            sign_in non_project_user
            get edit_rule_list_path(public_rule_list)
            expect(response).to have_http_status(:unauthorized)
          end
        end

        context "when a project user is signed in" do
          it "returns http unauthorized" do
            sign_in project_user
            get edit_rule_list_path(public_rule_list)
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end

  describe "GET /show" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get rule_list_path(public_rule_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the rule list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the rule list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get rule_list_path(public_rule_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the rule list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the rule list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get rule_list_path(public_rule_list)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /view_file" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get view_file_rule_list_path(public_rule_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the rule list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get view_file_rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the rule list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get view_file_rule_list_path(public_rule_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the rule list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the rule list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_rule_list_path(public_rule_list)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /view_file_content" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get view_file_content_rule_list_path(public_rule_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the rule list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get view_file_content_rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the rule list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get view_file_content_rule_list_path(public_rule_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the rule list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_content_rule_list_path(sensitive_rule_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the rule list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_content_rule_list_path(public_rule_list)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "POST /create" do
    let(:file) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/rule_lists/dive.rule")) }
    let(:params) { { rule_list: { name: "Test Rule List", description: "Test Description", file: file } } }
    let(:private_params) { { rule_list: { name: "Test Rule List", description: "Test Description", file: file, project_ids: [project.id] } } }

    context "when user is not signed in" do
      it "redirects to sign in page" do
        post rule_lists_path, params: params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when an admin user is signed in" do
      it "creates a new rule list" do
        sign_in admin
        post rule_lists_path, params: params
        expect(response).to redirect_to(rule_list_path(RuleList.last))
        expect(flash[:notice]).to eq("Rule list was successfully created.")
      end

      it "creates a new sensitive rule list" do
        sign_in admin
        post rule_lists_path, params: private_params
        expect(response).to redirect_to(rule_list_path(RuleList.last))
        expect(flash[:notice]).to eq("Rule list was successfully created.")
      end
    end

    context "when a non-project user is signed in" do
      it "creates a new public rule list" do
        sign_in non_project_user
        post rule_lists_path, params: params
        expect(response).to redirect_to(rule_list_path(RuleList.last))
        expect(flash[:notice]).to eq("Rule list was successfully created.")
      end

      it "fails to create a new sensitive rule list" do
        sign_in non_project_user
        post rule_lists_path, params: private_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when a project user is signed in" do
      it "creates a new public rule list" do
        sign_in project_user
        post rule_lists_path, params: params
        expect(response).to redirect_to(rule_list_path(RuleList.last))
        expect(flash[:notice]).to eq("Rule list was successfully created.")
      end

      it "creates a new sensitive rule list" do
        sign_in project_user
        post rule_lists_path, params: private_params
        expect(response).to redirect_to(rule_list_path(RuleList.last))
        expect(flash[:notice]).to eq("Rule list was successfully created.")
      end
    end
  end
end
