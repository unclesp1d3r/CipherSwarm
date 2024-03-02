require 'rails_helper'

RSpec.describe "Api::V1::Clients", type: :request do
  describe "GET /configuration" do
    it "returns http forbidden when anonymous" do
      get "/api/v1/client/configuration"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns http success when authenticated" do
      user = create(:user)
      agent = create(:agent)
      get "/api/v1/client/configuration", params: { token: agent.token }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /authenticate" do
    it "returns http forbidden" do
      get "/api/v1/client/authenticate"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns http success" do
      user = create(:user)
      agent = create(:agent)
      get "/api/v1/client/authenticate", params: { token: agent.token }
      expect(response).to have_http_status(:success)
    end
  end
end
