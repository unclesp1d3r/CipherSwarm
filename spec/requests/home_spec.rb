# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Homes", type: :request do
  describe "GET /index" do
    let!(:user) { create(:user) }

    it "redirects to the login page" do
      get "/"
      expect(response).to redirect_to new_user_session_path
    end

    it "returns http success" do
      sign_in user
      get "/"
      expect(response).to have_http_status(:success)
    end
  end
end
