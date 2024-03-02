# This file contains the RSpec tests for the "Api::V1::Client::Agents" controller.
# It tests the "GET /show" and "GET /update" endpoints to ensure they return a successful HTTP status.
require 'rails_helper'

RSpec.describe "Api::V1::Client::Agents", type: :request do
  describe "GET /show" do
    it "returns http forbidden when anonymous" do
      get "/api/v1/client/agents/show"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns http success when authenticated" do
      user = create(:user)
      agent = create(:agent)
      get "/api/v1/client/agents/show", params: { token: agent.token }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http forbidden" do
      get "/api/v1/client/agents/update"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
