# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "swagger_helper"

RSpec.describe "api/v1/client" do
  describe "Client API" do
    path "/api/v1/client/configuration" do
      get "Get Agent Configuration" do
        tags "Client"
        description "Returns the configuration for the agent."
        security [bearer_auth: []]
        produces "application/json"
        operationId "getConfiguration"

        response(200, "successful", use_as_request_example: true) do
          let!(:agent) { create(:agent) }
          let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

          schema "$ref" => "#/components/schemas/ConfigurationResponse"

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

            # Verify all resilience defaults are present and correct
            expect(data[:recommended_timeouts]).to eq(
              connect_timeout: 10, read_timeout: 30, write_timeout: 30, request_timeout: 60
            )
            expect(data[:recommended_retry]).to eq(
              max_attempts: 10, initial_delay: 1, max_delay: 300
            )
            expect(data[:recommended_circuit_breaker]).to eq(
              failure_threshold: 5, timeout: 30
            )
          end
        end

        response(401, "Unauthorized") do
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
        produces "application/json"
        operationId "authenticate"

        response(200, "successful", use_as_request_example: true) do
          let!(:agent) { create(:agent) }
          let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

          schema "$ref" => "#/components/schemas/AuthenticationResponse"

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

        response(401, "Unauthorized") do
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
