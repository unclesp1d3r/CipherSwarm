require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /" do
    it "returns http success" do
      get "/"
      # We redirect unauthenticated users to the login page
      expect(response).to have_http_status(301)
    end
  end
end
