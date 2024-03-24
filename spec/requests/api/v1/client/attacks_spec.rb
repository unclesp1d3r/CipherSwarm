require 'rails_helper'

RSpec.describe "Api::V1::Client::Attacks", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/client/attacks/index"
      expect(response).to have_http_status(:success)
    end
  end
end
