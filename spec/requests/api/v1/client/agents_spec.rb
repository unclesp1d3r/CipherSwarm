# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "api/v1/client/agents" do
  path "/api/v1/client/agents/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer, format: "int64" },
              required: true, description: "id"

    get "Gets an instance of an agent" do
      tags "Agents"
      description "Returns an agent"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "getAgent"

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(200, "successful") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/Agent"

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

      response 401, "Not authorized" do
        let(:agent) { create(:agent) }
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/ErrorObject"
        run_test!
      end
    end

    put "Updates the agent" do
      tags "Agents"
      description "Updates an agent"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "updateAgent"

      parameter name: :agent, in: :body, schema: {
        "$ref" => "#/components/schemas/AgentUpdate"
      }, require: true

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(200, "successful") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/Agent"
        after do |example|
          example.metadata[:response][:content] = {
            "application/json" => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test!
      end

      response 401, "Not authorized" do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/ErrorObject"
        run_test!
      end
    end
  end

  path "/api/v1/client/agents/{id}/heartbeat" do
    parameter name: :id, in: :path, schema: { type: :integer, format: "int64" },
              required: true, description: "id"

    post "Send a heartbeat for an agent" do
      tags "Agents"
      description "Send a heartbeat for an agent to keep it alive."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "sendHeartbeat"

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(204, "successful") do
        let(:agent) { create(:agent, state: "active") }
        let(:id) { agent.id }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        run_test!
      end

      response(200, "successful, but with server feedback") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/AgentHeartbeatResponse"

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

      response 401, "Not authorized" do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/ErrorObject"
        run_test!
      end
    end
  end

  path "/api/v1/client/agents/{id}/submit_benchmark" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" },
              required: true, description: "id"

    post("submit_benchmark agent") do
      tags "Agents"
      description "Submit a benchmark for an agent"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "submitBenchmark"

      parameter name: :hashcat_benchmarks, in: :body,
                schema: {
                  type: :array,
                  items: { "$ref" => "#/components/schemas/HashcatBenchmark" }
                }

      let(:agent) { create(:agent) }

      response(204, "successful") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }
        let(:hashcat_benchmarks) do
          [
            {
              hash_type: 1000,
              runtime: 1000,
              hash_speed: "1000",
              device: 1
            }
          ]
        end

        run_test!
      end

      response 400, "Bad request" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }
        let(:hashcat_benchmarks) { }

        run_test!
      end

      response 401, "Not authorized" do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }
        let(:hashcat_benchmarks) do
          [
            {
              hash_type: 1000,
              runtime: 1000,
              hash_speed: "1000",
              device: 1
            }
          ]
        end

        run_test!
      end
    end
  end

  path "/api/v1/client/agents/{id}/submit_error" do
    parameter name: :id, in: :path, schema: { type: :integer, format: "int64" },
              required: true, description: "id"

    post "Submit an error for an agent" do
      tags "Agents"
      description "Submit an error for an agent"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "submitErrorAgent"

      parameter name: :agent_error, in: :body, schema: {
        "$ref" => "#/components/schemas/AgentError"
      }, require: true

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(204, "successful") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:agent_error) {
          build(:agent_error,
                message: "The error message",
                metadata: nil,
                severity: "low")
        }

        run_test!
      end

      response(204, "successful, with metadata") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:agent_error) {
          build(:agent_error,
                message: "The error message",
                metadata: { error_date: Time.zone.now, key: "value" },
                severity: "low")
        }

        run_test!
      end

      response 404, "Task not found" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:agent_error) { build(:agent_error,
                                  agent: agent,
                                  task_id: 123456) }

        run_test!
      end

      response 401, "Not authorized" do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName
        let(:agent_error) { build(:agent_error) }

        run_test!
      end
    end
  end

  path "/api/v1/client/agents/{id}/shutdown" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" },
              required: true, description: "id"

    post("shutdown agent") do
      tags "Agents"
      description "Marks the agent as shutdown and offline, freeing any assigned tasks."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "setAgentShutdown"

      let(:agent) { create(:agent) }

      response 204, "successful" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }

        run_test!
      end

      response 401, "Not authorized" do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }

        run_test!
      end
    end
  end
end
