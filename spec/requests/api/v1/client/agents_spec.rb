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

      response(200, "successful", use_as_request_example: true) do
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

    put "Updates the agent" do
      tags "Agents"
      description "Updates an agent"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "updateAgent"

      parameter name: :agent, in: :body, schema: {
        type: :object,
        properties: {
          id: { type: :integer, format: :int64, description: "The id of the agent" },
          name: { type: :string, description: "The hostname of the agent" },
          client_signature: { type: :string, description: "The signature of the client" },
          operating_system: { type: :string, description: "The operating system of the agent" },
          devices: { type: :array, items: { type: :string, description: "The descriptive name of a GPU or CPU device." } }
        },
        required: %i[id name client_signature operating_system devices]
      }

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(200, "successful", use_as_request_example: true) do
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
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

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

  path "/api/v1/client/agents/{id}/heartbeat" do
    parameter name: :id, in: :path, schema: { type: :integer, format: :int64 },
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

        schema description: "The response to an agent heartbeat",
               type: :object,
               properties: {
                 state: { type: :string,
                          description: "The state of the agent:
                       * `pending` - The agent needs to perform the setup process again.
                       * `active` - The agent is ready to accept tasks, all is good.
                       * `error` - The agent has encountered an error and needs to be checked.
                       * `stopped` - The agent has been stopped by the user.",
                          enum: %w[pending stopped error] }
               },
               required: %i[state]

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

  path "/api/v1/client/agents/{id}/submit_benchmark" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" },
              required: true, description: "id"

    post("submit agent benchmarks") do
      tags "Agents"
      description "Submit a benchmark for an agent"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "submitBenchmark"

      parameter name: :hashcat_benchmarks, in: :body, schema: {
        type: :object,
        properties: {
          hashcat_benchmarks: {
            type: :array,
            items: { "$ref" => "#/components/schemas/HashcatBenchmark" }
          }
        }, required: %i[hashcat_benchmarks]
      }, required: true

      let(:agent) { create(:agent) }

      response(204, "successful") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }
        let(:hashcat_benchmarks) {
          {
            hashcat_benchmarks: [
              {
                hash_type: 1000,
                runtime: 1000,
                hash_speed: "1000",
                device: 1
              }
            ]
          }
        }

        run_test!
      end

      response 400, "Bad request" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }
        let(:hashcat_benchmarks) { }

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
        type: :object,
        properties: {
          message: { type: :string, description: "The error message" },
          metadata: { type: :object, nullable: true, description: "Additional metadata about the error",
                      properties: {
                        error_date: { type: :string, format: "date-time", description: "The date of the error" },
                        other: { type: :object, nullable: true, description: "Other metadata", additionalProperties: true }
                      },
                      required: %i[error_date] },
          severity: {
            type: :string,
            description: "The severity of the error:
                       * `info` - Informational message, no action required.
                       * `warning` - Non-critical error, no action required. Anticipated, but not necessarily problematic.
                       * `minor` - Minor error, no action required. Should be investigated, but the task can continue.
                       * `major` - Major error, action required. The task should be investigated and possibly restarted.
                       * `critical` - Critical error, action required. The task should be stopped and investigated.
                        * `fatal` - Fatal error, action required. The agent cannot continue with the task and should not be reattempted.",
            enum: %i[info warning minor major critical fatal]
          },
          agent_id: { type: :integer, format: :int64, description: "The agent that caused the error" },
          task_id: { type: :integer, nullable: true, format: :int64, description: "The task that caused the error, if any" }
        },
        required: %i[message severity agent_id]
      }, require: true

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(204, "successful") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:agent_error) {
          build(:agent_error,
                message: "The error message",
                metadata: nil,
                severity: "info")
        }

        run_test!
      end

      response(204, "successful, with metadata") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:agent_error) {
          build(:agent_error,
                message: "The error message",
                metadata: { error_date: Time.zone.now, key: "value" },
                severity: "info")
        }

        run_test!
      end

      response 404, "Task not found" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:agent_error) {
          build(:agent_error,
                agent: agent,
                task_id: 123456)
        }

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

      response 401, "Not authorized" do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName
        let(:agent_error) { build(:agent_error) }

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
