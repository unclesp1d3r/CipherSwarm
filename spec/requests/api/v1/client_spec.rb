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

          schema type: :object,
                 properties: {
                   config: {
                     "$ref" => "#/components/schemas/AdvancedAgentConfiguration"
                   },
                   api_version: { type: :integer, description: "The minimum accepted version of the API" },
                   benchmarks_needed: { type: :boolean, description: "Whether the agent needs to run benchmarks" },
                   recommended_timeouts: {
                     type: :object,
                     description: "Recommended timeout settings for agent HTTP connections",
                     additionalProperties: false,
                     properties: {
                       connect_timeout: { type: :integer, description: "TCP connect timeout in seconds" },
                       read_timeout: { type: :integer, description: "Read timeout in seconds" },
                       write_timeout: { type: :integer, description: "Write timeout in seconds" },
                       request_timeout: { type: :integer, description: "Overall request timeout in seconds" }
                     },
                     required: %i[connect_timeout read_timeout write_timeout request_timeout]
                   },
                   recommended_retry: {
                     type: :object,
                     description: "Recommended retry settings for agent HTTP requests",
                     additionalProperties: false,
                     properties: {
                       max_attempts: { type: :integer, description: "Maximum number of retry attempts" },
                       initial_delay: { type: :integer, description: "Initial retry delay in seconds" },
                       max_delay: { type: :integer, description: "Maximum retry delay in seconds" }
                     },
                     required: %i[max_attempts initial_delay max_delay]
                   },
                   recommended_circuit_breaker: {
                     type: :object,
                     description: "Recommended circuit breaker settings for agent connections",
                     additionalProperties: false,
                     properties: {
                       failure_threshold: { type: :integer, description: "Number of failures before circuit opens" },
                       timeout: { type: :integer, description: "Seconds before circuit half-opens for retry" }
                     },
                     required: %i[failure_threshold timeout]
                   }
                 },
                 required: %i[config api_version benchmarks_needed recommended_timeouts recommended_retry recommended_circuit_breaker]

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
            expect(data[:recommended_timeouts][:connect_timeout]).to eq(10)
            expect(data[:recommended_retry][:max_attempts]).to eq(10)
            expect(data[:recommended_circuit_breaker][:failure_threshold]).to eq(5)
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
