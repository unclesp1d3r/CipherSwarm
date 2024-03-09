require 'rails_helper'

RSpec.describe "Api::V1::Crackers", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/crackers/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/api/v1/crackers/show"
      expect(response).to have_http_status(:success)
    end
  end
end
