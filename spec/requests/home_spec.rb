require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /" do
    it "returns http redirect on anonymous" do
      get "/"
      # We redirect unauthenticated users to the login page
      expect(response).to have_http_status(301)
    end

    it "returns http success on authenticated" do
      user = create(:user)
      sign_in user
      get "/"
      expect(response).to have_http_status(200)
    end
  end
end
