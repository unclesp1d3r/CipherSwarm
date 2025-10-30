# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "WordLists" do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }

  let!(:sensitive_word_list) { create(:word_list, projects: [project], sensitive: true) }
  let!(:public_word_list) { create(:word_list, projects: [], sensitive: false) }

  describe "GET /index" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get word_lists_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when admin user is signed in" do
      it "returns http success" do
        sign_in admin
        get word_lists_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is signed in" do
      it "returns http success" do
        sign_in project_user
        get word_lists_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /new" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get new_word_list_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when an admin user is signed in" do
      it "returns http success" do
        sign_in admin
        get new_word_list_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when a project user is signed in" do
      it "returns http success" do
        sign_in project_user
        get new_word_list_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /edit" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get edit_word_list_path(public_word_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when word list is sensitive" do
      context "when an admin user is signed in" do
        it "returns http success" do
          sign_in admin
          get edit_word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when a non-project user is signed in" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get edit_word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when a project user is signed in" do
        it "returns http success" do
          sign_in project_user
          get edit_word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when word list is not sensitive" do
      context "when an admin user is signed in" do
        it "returns http success" do
          sign_in admin
          get edit_word_list_path(public_word_list)
          expect(response).to have_http_status(:success)
        end

        context "when a non-project user is signed in" do
          it "returns http unauthorized" do
            sign_in non_project_user
            get edit_word_list_path(public_word_list)
            expect(response).to have_http_status(:unauthorized)
          end
        end

        context "when a project user is signed in" do
          it "returns http unauthorized" do
            sign_in project_user
            get edit_word_list_path(public_word_list)
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end

  describe "GET /show" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get word_list_path(public_word_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the word list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the word list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get word_list_path(public_word_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the word list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the word list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get word_list_path(public_word_list)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /view_file" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get view_file_word_list_path(public_word_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the word list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get view_file_word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the word list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get view_file_word_list_path(public_word_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the word list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the word list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_word_list_path(public_word_list)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /view_file_content" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get view_file_content_word_list_path(public_word_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is signed in" do
      context "when the word list is sensitive" do
        it "returns http unauthorized" do
          sign_in non_project_user
          get view_file_content_word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the word list is not sensitive" do
        it "returns http success" do
          sign_in non_project_user
          get view_file_content_word_list_path(public_word_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when a project user is signed in" do
      context "when the word list is sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_content_word_list_path(sensitive_word_list)
          expect(response).to have_http_status(:success)
        end
      end

      context "when the word list is not sensitive" do
        it "returns http success" do
          sign_in project_user
          get view_file_content_word_list_path(public_word_list)
          expect(response).to have_http_status(:success)
        end
      end
    end

    describe "POST /create" do
      let(:file) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/word_lists/top-passwords.txt")) }
      let(:params) { { word_list: { name: "Test Word List", description: "Test Description", file: file } } }
      let(:private_params) { { word_list: { name: "Test Word List", description: "Test Description", file: file, project_ids: [project.id] } } }

      context "when user is not signed in" do
        it "redirects to sign in page" do
          post word_lists_path, params: params
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when an admin user is signed in" do
        it "creates a new word list" do
          sign_in admin
          post word_lists_path, params: params
          expect(response).to redirect_to(word_list_path(WordList.last))
          expect(flash[:notice]).to eq("Word list was successfully created.")
        end

        it "creates a new sensitive word list" do
          sign_in admin
          post word_lists_path, params: private_params
          expect(response).to redirect_to(word_list_path(WordList.last))
          expect(flash[:notice]).to eq("Word list was successfully created.")
        end
      end

      context "when a non-project user is signed in" do
        it "creates a new public word list" do
          sign_in non_project_user
          post word_lists_path, params: params
          expect(response).to redirect_to(word_list_path(WordList.last))
          expect(flash[:notice]).to eq("Word list was successfully created.")
        end

        it "fails to create a new sensitive word list" do
          sign_in non_project_user
          post word_lists_path, params: private_params
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when a project user is signed in" do
        it "creates a new public word list" do
          sign_in project_user
          post word_lists_path, params: params
          expect(response).to redirect_to(word_list_path(WordList.last))
          expect(flash[:notice]).to eq("Word list was successfully created.")
        end

        it "creates a new sensitive word list" do
          sign_in project_user
          post word_lists_path, params: private_params
          expect(response).to redirect_to(word_list_path(WordList.last))
          expect(flash[:notice]).to eq("Word list was successfully created.")
        end
      end
    end
  end
end


describe "DELETE /destroy" do
    let!(:creator_user) { create(:user) }
    let!(:user_owned_word_list) { create(:word_list, creator: creator_user) }

    context "when user is not signed in" do
      it "redirects to sign in page" do
        delete word_list_path(user_owned_word_list)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when non-admin user is signed in" do
      before { sign_in creator_user }

      it "successfully deletes their own word list" do
        expect {
          delete word_list_path(user_owned_word_list)
        }.to change(WordList, :count).by(-1)

        expect(response).to redirect_to(word_lists_path)
        expect(flash[:notice]).to eq("Word list was successfully destroyed.")
        expect(WordList.exists?(user_owned_word_list.id)).to be_falsey
      end

      it "fails to delete a word list they did not create" do
        other_user_word_list = create(:word_list, creator: create(:user))
        expect {
          delete word_list_path(other_user_word_list)
        }.not_to change(WordList, :count)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin user is signed in" do
      before { sign_in admin }

      it "successfully deletes any word list" do
        word_list_to_delete = create(:word_list, creator: create(:user))

        expect {
          delete word_list_path(word_list_to_delete)
        }.to change(WordList, :count).by(-1)

        expect(response).to redirect_to(word_lists_path)
        expect(flash[:notice]).to eq("Word list was successfully destroyed.")
        expect(WordList.exists?(word_list_to_delete.id)).to be_falsey
      end
    end
  end