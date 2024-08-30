# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Agents", type: :request do
  let!(:regular_user) { create(:user, role: :basic) }
  let!(:agent) { create(:agent, user: regular_user) }

  describe "GET /index" do
    it "returns http success" do
      sign_in regular_user
      get agents_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end

    it "redirects to login page if not logged in" do
      get agents_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /:id" do
    it "returns http success" do
      sign_in regular_user
      get agent_path(agent)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      sign_in regular_user
      get new_agent_path
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      sign_in regular_user
      get edit_agent_path(agent)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end
  end
end
