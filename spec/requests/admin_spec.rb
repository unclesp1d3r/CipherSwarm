require 'rails_helper'

RSpec.describe "Admins", type: :request do
  describe "GET /index" do
    it "returns http redirect" do
      get "/admin/index"
      expect(response).to have_http_status(401)
    end

    it "returns http success on authenticated admin" do
      user = create(:user, role: :admin)
      sign_in user
      get "/admin/index"
      expect(response).to have_http_status(:success)
    end

    it "returns http failure on authenticated non-admin" do
      user = create(:user, role: :basic)
      sign_in user
      get "/admin/index"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
