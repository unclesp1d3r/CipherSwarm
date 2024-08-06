# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "api/v1/client" do
  describe "Client API" do
    path "/api/v1/client/configuration" do
      get "Get Agent Configuration" do
        tags "Client"
        description "Returns the configuration for the agent."
        security [bearer_auth: []]
        consumes "application/json"
        produces "application/json"
        operationId "getConfiguration"

        response(200, "successful", use_as_request_example: true) do
          let!(:agent) { create(:agent) }
          let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

          schema type: :object,
                 properties: {
                   config: {
                     "$ref" => "#/components/schemas/AdvancedAgentConfiguration"
                   },
                   api_version: { type: :integer, description: "The minimum accepted version of the API" }
                 },
                 required: %i[config api_version]

          after do |example|
            content = example.metadata[:response][:content] || {}
            example_spec = {
              "application/json" => {
                examples: {
                  test_example: {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
            example.metadata[:response][:content] = content.deep_merge(example_spec)
          end

          run_test! do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body, symbolize_names: true)
            expect(data[:config][:agent_update_interval]).to be_present
          end
        end

        response(401, "unauthorized") do
          let(:Authorization) { nil } # rubocop:disable RSpec/VariableName

          schema "$ref" => "#/components/schemas/ErrorObject"

          after do |example|
            content = example.metadata[:response][:content] || {}
            example_spec = {
              "application/json" => {
                examples: {
                  test_example: {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
            example.metadata[:response][:content] = content.deep_merge(example_spec)
          end

          run_test!
        end
      end
    end

    path "/api/v1/client/authenticate" do
      get "Authenticate Client" do
        tags "Client"
        description "Authenticates the client. This is used to verify that the client is able to connect to the server."
        security [bearer_auth: []]
        consumes "application/json"
        produces "application/json"
        operationId "authenticate"

        response(200, "successful", use_as_request_example: true) do
          let!(:agent) { create(:agent) }
          let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

          schema type: :object,
                 properties: {
                   authenticated: { type: :boolean },
                   agent_id: { type: :integer, format: :int64 }
                 },
                 required: %i[authenticated agent_id]

          after do |example|
            content = example.metadata[:response][:content] || {}
            example_spec = {
              "application/json" => {
                examples: {
                  test_example: {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
            example.metadata[:response][:content] = content.deep_merge(example_spec)
          end

          run_test!
        end

        response(401, "unauthorized") do
          let(:Authorization) { nil } # rubocop:disable RSpec/VariableName

          schema "$ref" => "#/components/schemas/ErrorObject"

          after do |example|
            content = example.metadata[:response][:content] || {}
            example_spec = {
              "application/json" => {
                examples: {
                  test_example: {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
            example.metadata[:response][:content] = content.deep_merge(example_spec)
          end

          run_test!
        end
      end
    end
  end
end
