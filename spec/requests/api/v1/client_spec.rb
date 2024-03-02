require 'rails_helper'

RSpec.describe "Api::V1::Clients", type: :request do
  describe "GET /configuration" do
    it "returns http success" do
      get "/api/v1/client/configuration"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /authenticate" do
    it "returns http forbidden" do
      get "/api/v1/client/authenticate"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
