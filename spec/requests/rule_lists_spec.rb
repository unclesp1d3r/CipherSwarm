# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "RuleLists", type: :request do
  let(:project) { create(:project) }
  let(:user) { create(:user, projects: [project]) }
  let(:rule_list) { create(:rule_list, projects: [project]) }

  describe "GET /index" do
    it "returns http success" do
      sign_in user
      get rule_lists_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      sign_in user
      get new_rule_list_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      sign_in user
      get edit_rule_list_path(rule_list)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      sign_in user
      get rule_list_path(rule_list)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
    end
  end

  describe "GET /view_file" do
    it "returns http success" do
      sign_in user
      get view_file_rule_list_path(rule_list)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:view_file)
    end
  end

  describe "GET /view_file_content" do
    it "returns http success" do
      sign_in user
      get view_file_content_rule_list_path(rule_list)
      expect(response).to have_http_status(:success)
    end
  end
end