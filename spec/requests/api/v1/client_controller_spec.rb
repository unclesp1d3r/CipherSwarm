require "rails_helper"

RSpec.describe Api::V1::ClientController do
  context "GET /api/v1/client/authenticate" do
    it "returns a JSON response with agent's authentication token"
    it "returns an unauthorized JSON response"
  end

  context "GET /api/v1/client/configuration" do
    it "returns a JSON response with agent's advanced configuration and API version"
  end
end
