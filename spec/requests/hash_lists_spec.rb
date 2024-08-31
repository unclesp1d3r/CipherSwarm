# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "HashLists", type: :request do
  let(:project) { create(:project) }
  let(:user) { create(:user, projects: [project]) }
  let(:hash_list) { create(:hash_list, project: project) }

  describe "GET /index" do
    it "returns http success" do
      sign_in user
      get hash_lists_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      sign_in user
      get new_hash_list_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      sign_in user
      get edit_hash_list_path(hash_list)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      sign_in user
      get hash_list_path(hash_list)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
    end
  end
end
