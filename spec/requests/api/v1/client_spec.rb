# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "api/v1/client" do
  describe "Client API" do
    path "/api/v1/client/configuration" do
      get "Obtains the configuration for the agent" do
        tags "Client"
        security [bearer_auth: []]
        consumes "application/json"
        produces "application/json"
        operationId "configuration"
        response(200, "successful") do
          let!(:agent) { create(:agent) }
          let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

          schema type: :object,
                 properties: {
                   config: {
                     ref: "#/components/schemas/advanced_agent_configuration",
                     nullable: true
                   },
                   api_version: { type: :integer }
                 }

          after do |example|
            example.metadata[:response][:content] = {
              "application/json" => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          run_test!
        end

        response(401, "unauthorized") do
          let(:Authorization) { nil } # rubocop:disable RSpec/VariableName

          run_test!
        end
      end
    end

    path "/api/v1/client/authenticate" do
      get "Authenticates the client. This is used to verify that the client is able to connect to the server." do
        tags "Client"
        security [bearer_auth: []]
        consumes "application/json"
        produces "application/json"
        operationId "authenticate"
        response(200, "successful") do
          let!(:agent) { create(:agent) }
          let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

          schema type: :object,
                 properties: {
                   authenticated: { type: :boolean },
                   agent_id: { type: :integer }
                 },
                 required: %w[authenticated agent_id]
          after do |example|
            example.metadata[:response][:content] = {
              "application/json" => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          run_test!
        end

        response(401, "unauthorized") do
          let(:Authorization) { nil } # rubocop:disable RSpec/VariableName

          run_test!
        end
      end
    end
  end
end
