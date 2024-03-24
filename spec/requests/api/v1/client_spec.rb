require "rails_helper"

RSpec.describe Api::V1::ClientController, type: :controller do
  describe "#authenticate" do
    it "returns a JSON response with authenticated true and agent_id" do
      # Create a test agent
      agent = create(:agent)

      # Stub the @agent instance variable
      allow(controller).to receive(:authenticate_agent!).and_return(true)
      allow(controller).to receive(:current_agent).and_return(agent)

      # Make a request to the authenticate action
      get :authenticate

      # Expect the response to have a status of 200
      expect(response).to have_http_status(200)

      # Parse the JSON response
      json_response = JSON.parse(response.body)

      # Expect the JSON response to have authenticated true and agent_id
      expect(json_response["authenticated"]).to eq(true)
      expect(json_response["agent_id"]).to eq(agent.id)
    end
  end
end
require "rails_helper"

RSpec.describe Api::V1::ClientController, type: :controller do
  describe "#configuration" do
    it "returns a JSON response with agent's advanced configuration and API version" do
      # Create a test agent
      agent = create(:agent)

      # Stub the @agent instance variable
      allow(controller).to receive(:authenticate_agent!).and_return(true)
      allow(controller).to receive(:current_agent).and_return(agent)

      # Make a request to the configuration action
      get :configuration

      # Expect the response to have a status of 200
      expect(response).to have_http_status(200)

      # Parse the JSON response
      json_response = JSON.parse(response.body)

      # Expect the JSON response to have the agent's advanced configuration and API version
      expect(json_response["config"]).to eq(agent.advanced_configuration)
      expect(json_response["api_version"]).to eq(1)
    end
  end
end
