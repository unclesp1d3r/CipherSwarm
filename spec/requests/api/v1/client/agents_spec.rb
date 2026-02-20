# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "swagger_helper"

RSpec.describe "api/v1/client/agents" do
  describe "API Request Logging" do
    let(:agent) { create(:agent) }

    context "when making a successful API request" do
      it "logs APIRequest START and COMPLETE messages" do
        allow(Rails.logger).to receive(:info)

        get "/api/v1/client/agents/#{agent.id}",
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] START.*Agent #{agent.id}/).at_least(:once)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE.*Agent #{agent.id}.*Status 200/).at_least(:once)
      end

      it "includes duration in COMPLETE log" do
        allow(Rails.logger).to receive(:info)

        get "/api/v1/client/agents/#{agent.id}",
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE.*Duration.*ms/).at_least(:once)
      end
    end

    context "when authentication fails" do
      it "returns unauthorized status" do
        get "/api/v1/client/agents/#{agent.id}",
            headers: { "Authorization" => "Bearer InvalidToken" }

        expect(response).to have_http_status(:unauthorized)
      end

      it "does not raise when logging with invalid token" do
        expect {
          get "/api/v1/client/agents/#{agent.id}",
              headers: { "Authorization" => "Bearer InvalidToken" }
        }.not_to raise_error
      end
    end

    context "when request contains invalid JSON" do
      it "logs APIError JSON_PARSE_ERROR" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        put "/api/v1/client/agents/#{agent.id}",
            headers: {
              "Authorization" => "Bearer #{agent.token}",
              "Content-Type" => "application/json"
            },
            params: "{invalid json"

        expect(response).to have_http_status(:bad_request)
        expect(Rails.logger).to have_received(:error).with(/\[APIError\] JSON_PARSE_ERROR/).at_least(:once)
      end
    end

    context "when heartbeat updates agent state" do
      let(:active_agent) { create(:agent, state: "active") }

      it "logs APIRequest without raising errors" do
        allow(Rails.logger).to receive(:info)

        expect {
          post "/api/v1/client/agents/#{active_agent.id}/heartbeat",
               headers: { "Authorization" => "Bearer #{active_agent.token}" }
        }.not_to raise_error

        expect(response).to have_http_status(:success)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE/).at_least(:once)
      end
    end
  end

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
          host_name: { type: :string, description: "The hostname of the agent" },
          client_signature: { type: :string, description: "The signature of the client" },
          operating_system: { type: :string, description: "The operating system of the agent" },
          devices: { type: :array, items: { type: :string, description: "The descriptive name of a GPU or CPU device." } }
        },
        required: %i[id host_name client_signature operating_system devices]
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

    # NOTE: The `in: :body` parameter syntax is OpenAPI 2.0 style, which is technically invalid
    # for OpenAPI 3.0. This is a known limitation of rswag 2.x. The generated swagger.json will
    # contain this as a parameter instead of a requestBody, but most tools handle this gracefully.
    # Consider upgrading to rswag 3.x for proper OpenAPI 3.0 requestBody support.
    parameter name: :heartbeat_body, in: :body, required: false, schema: {
      type: :object,
      properties: {
        activity: {
          type: :string,
          description: "Current agent activity state. Known values: starting, benchmarking, " \
                       "updating, downloading, waiting, cracking, stopping. " \
                       "Future versions may support additional values.",
          example: "cracking",
          nullable: true
        }
      }
    }

    post "Send a heartbeat for an agent" do
      tags "Agents"
      description "Send a heartbeat for an agent to keep it alive. Optionally accepts an 'activity' " \
                  "parameter in the request body to track the agent's current activity state."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "sendHeartbeat"

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(200, "successful, but with server feedback") do
        let(:agent) { create(:agent, state: "pending") }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema description: "The response to an agent heartbeat",
               type: :object,
               properties: {
                 state: { type: :string,
                          description: "The state of the agent:
                       * `pending` - The agent needs to perform the setup process again.
                       * `active` - The agent is ready to accept tasks, all is good.
                       * `error` - The agent has encountered an error and needs to be checked.
                       * `stopped` - The agent has been stopped by the user.
                       * `offline` - The agent has not checked in within the configured threshold and is considered offline.",
                          enum: %w[pending active stopped error offline] }
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

      # Activity parameter tests
      response(204, "successful with activity parameter") do
        let(:agent) { create(:agent, state: "active") }
        let(:id) { agent.id }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:heartbeat_body) { { activity: "cracking" } }

        run_test! do
          expect(response).to have_http_status(:no_content)
          expect(agent.reload.current_activity).to eq("cracking")
        end
      end

      response(204, "successful with null activity") do
        let(:agent) { create(:agent, state: "active", current_activity: "waiting") }
        let(:id) { agent.id }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:heartbeat_body) { { activity: nil } }

        run_test! do
          expect(response).to have_http_status(:no_content)
          expect(agent.reload.current_activity).to be_nil
        end
      end

      response(204, "successful with empty request body") do
        let(:agent) { create(:agent, state: "active") }
        let(:id) { agent.id }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:heartbeat_body) { {} }

        run_test! do
          expect(response).to have_http_status(:no_content)
        end
      end

      response(204, "successful with unknown activity value (forward compatibility)") do
        let(:agent) { create(:agent, state: "active") }
        let(:id) { agent.id }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:heartbeat_body) { { activity: "future_activity_type" } }

        run_test! do
          expect(response).to have_http_status(:no_content)
          expect(agent.reload.current_activity).to eq("future_activity_type")
        end
      end

      response(204, "successful with invalid activity ignored") do
        let(:agent) { create(:agent, state: "active") }
        let(:id) { agent.id }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:heartbeat_body) { { activity: "a" * 100 } }

        run_test! do
          # Heartbeat should succeed even if activity validation fails
          expect(response).to have_http_status(:no_content)
          # Activity should not be persisted due to length validation (max 50 chars)
          expect(agent.reload.current_activity).to be_nil
        end
      end

      # Basic heartbeat test - placed last so "successful" becomes the swagger 204 description
      response(204, "successful") do
        let(:agent) { create(:agent, state: "active") }
        let(:id) { agent.id }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

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

        run_test! do
          expect(response).to have_http_status(:no_content)
          expect(agent.hashcat_benchmarks.reload.count).to eq(1)
        end
      end

      response(204, "successful, extended benchmarks") do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }
        let(:hashcat_benchmarks) {
          { hashcat_benchmarks: [
            { "hash_type" => 0, "runtime" => 4294967295, "hash_speed" => 3511163292, "device" => 1 },
            { "hash_type" => 10, "runtime" => 4294967295, "hash_speed" => 3458462141, "device" => 1 },
            { "hash_type" => 11, "runtime" => 4294967295, "hash_speed" => 3486265305, "device" => 1 },
            { "hash_type" => 12, "runtime" => 4294967295, "hash_speed" => 3495298845, "device" => 1 },
            { "hash_type" => 20, "runtime" => 4294967295, "hash_speed" => 1968492556, "device" => 1 },
            { "hash_type" => 21, "runtime" => 4294967295, "hash_speed" => 1916519990, "device" => 1 },
            { "hash_type" => 22, "runtime" => 4294967295, "hash_speed" => 1921183590, "device" => 1 },
            { "hash_type" => 23, "runtime" => 4294967295, "hash_speed" => 1920386430, "device" => 1 },
            { "hash_type" => 24, "runtime" => 4294967295, "hash_speed" => 1913078023, "device" => 1 },
            { "hash_type" => 30, "runtime" => 4294967295, "hash_speed" => 3534417253, "device" => 1 },
            { "hash_type" => 40, "runtime" => 4294967295, "hash_speed" => 2036008130, "device" => 1 },
            { "hash_type" => 50, "runtime" => 4294967295, "hash_speed" => 580777706, "device" => 1 },
            { "hash_type" => 60, "runtime" => 4294967295, "hash_speed" => 1155555126, "device" => 1 },
            { "hash_type" => 70, "runtime" => 4294967295, "hash_speed" => 3526987031, "device" => 1 },
            { "hash_type" => 100, "runtime" => 4294967295, "hash_speed" => 1456355555, "device" => 1 },
            { "hash_type" => 101, "runtime" => 4294967295, "hash_speed" => 1470621348, "device" => 1 },
            { "hash_type" => 110, "runtime" => 4294967295, "hash_speed" => 1449623363, "device" => 1 },
            { "hash_type" => 111, "runtime" => 4294967295, "hash_speed" => 1476006818, "device" => 1 },
            { "hash_type" => 112, "runtime" => 4294967295, "hash_speed" => 1450735843, "device" => 1 },
            { "hash_type" => 120, "runtime" => 4294967295, "hash_speed" => 1035343022, "device" => 1 },
            { "hash_type" => 121, "runtime" => 4294967295, "hash_speed" => 1044040947, "device" => 1 },
            { "hash_type" => 122, "runtime" => 4294967295, "hash_speed" => 1047381330, "device" => 1 },
            { "hash_type" => 124, "runtime" => 4294967295, "hash_speed" => 1033971157, "device" => 1 },
            { "hash_type" => 125, "runtime" => 4294967295, "hash_speed" => 1023890636, "device" => 1 },
            { "hash_type" => 130, "runtime" => 4294967295, "hash_speed" => 1445564018, "device" => 1 },
            { "hash_type" => 131, "runtime" => 4294967295, "hash_speed" => 1410561291, "device" => 1 },
            { "hash_type" => 132, "runtime" => 4294967295, "hash_speed" => 1434900553, "device" => 1 },
            { "hash_type" => 133, "runtime" => 4294967295, "hash_speed" => 1472799903, "device" => 1 },
            { "hash_type" => 140, "runtime" => 4294967295, "hash_speed" => 1009565748, "device" => 1 },
            { "hash_type" => 141, "runtime" => 4294967295, "hash_speed" => 1030968982, "device" => 1 },
            { "hash_type" => 150, "runtime" => 4294967295, "hash_speed" => 121899093, "device" => 1 },
            { "hash_type" => 160, "runtime" => 4294967295, "hash_speed" => 545636008, "device" => 1 },
            { "hash_type" => 170, "runtime" => 4294967295, "hash_speed" => 1465371021, "device" => 1 },
            { "hash_type" => 200, "runtime" => 4294967295, "hash_speed" => 12972283187, "device" => 1 },
            { "hash_type" => 300, "runtime" => 4294967295, "hash_speed" => 490482992, "device" => 1 },
            { "hash_type" => 400, "runtime" => 4294967295, "hash_speed" => 1065353, "device" => 1 },
            { "hash_type" => 500, "runtime" => 4294967295, "hash_speed" => 1434762, "device" => 1 },
            { "hash_type" => 501, "runtime" => 4294967295, "hash_speed" => 1416037, "device" => 1 },
            { "hash_type" => 900, "runtime" => 4294967295, "hash_speed" => 6135457207, "device" => 1 },
            { "hash_type" => 1000, "runtime" => 4294967295, "hash_speed" => 6127754009, "device" => 1 },
            { "hash_type" => 1100, "runtime" => 4294967295, "hash_speed" => 67711913, "device" => 1 },
            { "hash_type" => 1300, "runtime" => 4294967295, "hash_speed" => 519700023, "device" => 1 },
            { "hash_type" => 1400, "runtime" => 4294967295, "hash_speed" => 537008386, "device" => 1 },
            { "hash_type" => 1410, "runtime" => 4294967295, "hash_speed" => 523911438, "device" => 1 },
            { "hash_type" => 1411, "runtime" => 4294967295, "hash_speed" => 529943490, "device" => 1 },
            { "hash_type" => 1420, "runtime" => 4294967295, "hash_speed" => 471303209, "device" => 1 },
            { "hash_type" => 1421, "runtime" => 4294967295, "hash_speed" => 466837776, "device" => 1 },
            { "hash_type" => 1430, "runtime" => 4294967295, "hash_speed" => 522964246, "device" => 1 },
            { "hash_type" => 1440, "runtime" => 4294967295, "hash_speed" => 474737294, "device" => 1 },
            { "hash_type" => 1441, "runtime" => 4294967295, "hash_speed" => 439326394, "device" => 1 },
            { "hash_type" => 1450, "runtime" => 4294967295, "hash_speed" => 100032292, "device" => 1 },
            { "hash_type" => 1460, "runtime" => 4294967295, "hash_speed" => 201329813, "device" => 1 },
            { "hash_type" => 1470, "runtime" => 4294967295, "hash_speed" => 540799277, "device" => 1 },
            { "hash_type" => 1500, "runtime" => 4294967295, "hash_speed" => 9679460, "device" => 1 },
            { "hash_type" => 1600, "runtime" => 4294967295, "hash_speed" => 1429652, "device" => 1 },
            { "hash_type" => 1700, "runtime" => 4294967295, "hash_speed" => 98387398, "device" => 1 },
            { "hash_type" => 1710, "runtime" => 4294967295, "hash_speed" => 105865973, "device" => 1 },
            { "hash_type" => 1711, "runtime" => 4294967295, "hash_speed" => 105751197, "device" => 1 },
            { "hash_type" => 1720, "runtime" => 4294967295, "hash_speed" => 100518950, "device" => 1 },
            { "hash_type" => 1722, "runtime" => 4294967295, "hash_speed" => 101014016, "device" => 1 },
            { "hash_type" => 1730, "runtime" => 4294967295, "hash_speed" => 106955260, "device" => 1 },
            { "hash_type" => 1731, "runtime" => 4294967295, "hash_speed" => 106832668, "device" => 1 },
            { "hash_type" => 1740, "runtime" => 4294967295, "hash_speed" => 101325151, "device" => 1 },
            { "hash_type" => 1750, "runtime" => 4294967295, "hash_speed" => 15285810, "device" => 1 },
            { "hash_type" => 1760, "runtime" => 4294967295, "hash_speed" => 32713817, "device" => 1 },
            { "hash_type" => 1770, "runtime" => 4294967295, "hash_speed" => 106797306, "device" => 1 },
            { "hash_type" => 2000, "runtime" => 4294967295, "hash_speed" => 710616693580, "device" => 1 },
            { "hash_type" => 2100, "runtime" => 4294967295, "hash_speed" => 53420, "device" => 1 },
            { "hash_type" => 2400, "runtime" => 4294967295, "hash_speed" => 2657934689, "device" => 1 },
            { "hash_type" => 2410, "runtime" => 4294967295, "hash_speed" => 2598449809, "device" => 1 },
            { "hash_type" => 2600, "runtime" => 4294967295, "hash_speed" => 67963573, "device" => 1 },
            { "hash_type" => 2611, "runtime" => 4294967295, "hash_speed" => 67511366, "device" => 1 },
            { "hash_type" => 2612, "runtime" => 4294967295, "hash_speed" => 72071800, "device" => 1 },
            { "hash_type" => 2711, "runtime" => 4294967295, "hash_speed" => 69748668, "device" => 1 },
            { "hash_type" => 2811, "runtime" => 4294967295, "hash_speed" => 76250368, "device" => 1 },
            { "hash_type" => 3000, "runtime" => 4294967295, "hash_speed" => 386696538, "device" => 1 },
            { "hash_type" => 3100, "runtime" => 4294967295, "hash_speed" => 50474187, "device" => 1 },
            { "hash_type" => 3200, "runtime" => 4294967295, "hash_speed" => 2219, "device" => 1 },
            { "hash_type" => 3500, "runtime" => 4294967295, "hash_speed" => 74579350, "device" => 1 },
            { "hash_type" => 3710, "runtime" => 4294967295, "hash_speed" => 66109747, "device" => 1 },
            { "hash_type" => 3711, "runtime" => 4294967295, "hash_speed" => 848534088, "device" => 1 },
            { "hash_type" => 3800, "runtime" => 4294967295, "hash_speed" => 1937966241, "device" => 1 },
            { "hash_type" => 3910, "runtime" => 4294967295, "hash_speed" => 150159904, "device" => 1 },
            { "hash_type" => 4010, "runtime" => 4294967295, "hash_speed" => 335606966, "device" => 1 },
            { "hash_type" => 4110, "runtime" => 4294967295, "hash_speed" => 200398878, "device" => 1 },
            { "hash_type" => 4300, "runtime" => 4294967295, "hash_speed" => 60406627, "device" => 1 },
            { "hash_type" => 4400, "runtime" => 4294967295, "hash_speed" => 739312387, "device" => 1 },
            { "hash_type" => 4410, "runtime" => 4294967295, "hash_speed" => 515112557, "device" => 1 },
            { "hash_type" => 4500, "runtime" => 4294967295, "hash_speed" => 543796706, "device" => 1 },
            { "hash_type" => 4510, "runtime" => 4294967295, "hash_speed" => 511929697, "device" => 1 },
            { "hash_type" => 4520, "runtime" => 4294967295, "hash_speed" => 296821046, "device" => 1 },
            { "hash_type" => 4521, "runtime" => 4294967295, "hash_speed" => 296349177, "device" => 1 },
            { "hash_type" => 4522, "runtime" => 4294967295, "hash_speed" => 445337934, "device" => 1 },
            { "hash_type" => 4700, "runtime" => 4294967295, "hash_speed" => 765497439, "device" => 1 },
            { "hash_type" => 4710, "runtime" => 4294967295, "hash_speed" => 707287620, "device" => 1 },
            { "hash_type" => 4711, "runtime" => 4294967295, "hash_speed" => 709358532, "device" => 1 },
            { "hash_type" => 4800, "runtime" => 4294967295, "hash_speed" => 2386899183, "device" => 1 },
            { "hash_type" => 4900, "runtime" => 4294967295, "hash_speed" => 939926384, "device" => 1 },
            { "hash_type" => 5000, "runtime" => 4294967295, "hash_speed" => 470622345, "device" => 1 },
            { "hash_type" => 5100, "runtime" => 4294967295, "hash_speed" => 2393966431, "device" => 1 },
            { "hash_type" => 5200, "runtime" => 4294967295, "hash_speed" => 226222, "device" => 1 },
            { "hash_type" => 5300, "runtime" => 4294967295, "hash_speed" => 109713807, "device" => 1 },
            { "hash_type" => 5400, "runtime" => 4294967295, "hash_speed" => 49364498, "device" => 1 },
            { "hash_type" => 5500, "runtime" => 4294967295, "hash_speed" => 3793068475, "device" => 1 },
            { "hash_type" => 5600, "runtime" => 4294967295, "hash_speed" => 249649807, "device" => 1 },
            { "hash_type" => 5700, "runtime" => 4294967295, "hash_speed" => 535961920, "device" => 1 },
            { "hash_type" => 5800, "runtime" => 4294967295, "hash_speed" => 824414, "device" => 1 },
            { "hash_type" => 6000, "runtime" => 4294967295, "hash_speed" => 803439175, "device" => 1 },
            { "hash_type" => 6100, "runtime" => 4294967295, "hash_speed" => 49955384, "device" => 1 },
            { "hash_type" => 6211, "runtime" => 4294967295, "hash_speed" => 46185, "device" => 1 },
            { "hash_type" => 6212, "runtime" => 4294967295, "hash_speed" => 26031, "device" => 1 },
            { "hash_type" => 6213, "runtime" => 4294967295, "hash_speed" => 17887, "device" => 1 },
            { "hash_type" => 6221, "runtime" => 4294967295, "hash_speed" => 34157, "device" => 1 },
            { "hash_type" => 6222, "runtime" => 4294967295, "hash_speed" => 14839, "device" => 1 },
            { "hash_type" => 6223, "runtime" => 4294967295, "hash_speed" => 12315, "device" => 1 },
            { "hash_type" => 6231, "runtime" => 4294967295, "hash_speed" => 9244, "device" => 1 },
            { "hash_type" => 6232, "runtime" => 4294967295, "hash_speed" => 4667, "device" => 1 },
            { "hash_type" => 6233, "runtime" => 4294967295, "hash_speed" => 3125, "device" => 1 },
            { "hash_type" => 6241, "runtime" => 4294967295, "hash_speed" => 91439, "device" => 1 },
            { "hash_type" => 6242, "runtime" => 4294967295, "hash_speed" => 50996, "device" => 1 },
            { "hash_type" => 6243, "runtime" => 4294967295, "hash_speed" => 35394, "device" => 1 },
            { "hash_type" => 6300, "runtime" => 4294967295, "hash_speed" => 1418113, "device" => 1 },
            { "hash_type" => 6400, "runtime" => 4294967295, "hash_speed" => 3024098, "device" => 1 },
            { "hash_type" => 6500, "runtime" => 4294967295, "hash_speed" => 513741, "device" => 1 },
            { "hash_type" => 6600, "runtime" => 4294967295, "hash_speed" => 535818, "device" => 1 },
            { "hash_type" => 6700, "runtime" => 4294967295, "hash_speed" => 6944763, "device" => 1 },
            { "hash_type" => 6800, "runtime" => 4294967295, "hash_speed" => 413682, "device" => 1 },
            { "hash_type" => 6900, "runtime" => 4294967295, "hash_speed" => 116639664, "device" => 1 },
            { "hash_type" => 7000, "runtime" => 4294967295, "hash_speed" => 1168614634, "device" => 1 },
            { "hash_type" => 7100, "runtime" => 4294967295, "hash_speed" => 35221, "device" => 1 },
            { "hash_type" => 7200, "runtime" => 4294967295, "hash_speed" => 35740, "device" => 1 },
            { "hash_type" => 7300, "runtime" => 4294967295, "hash_speed" => 141665957, "device" => 1 },
            { "hash_type" => 7400, "runtime" => 4294967295, "hash_speed" => 38854, "device" => 1 },
            { "hash_type" => 7401, "runtime" => 4294967295, "hash_speed" => 39123, "device" => 1 },
            { "hash_type" => 7500, "runtime" => 4294967295, "hash_speed" => 47962858, "device" => 1 },
            { "hash_type" => 7700, "runtime" => 4294967295, "hash_speed" => 633520853, "device" => 1 },
            { "hash_type" => 7701, "runtime" => 4294967295, "hash_speed" => 599646728, "device" => 1 },
            { "hash_type" => 7800, "runtime" => 4294967295, "hash_speed" => 147842932, "device" => 1 },
            { "hash_type" => 7801, "runtime" => 4294967295, "hash_speed" => 148240050, "device" => 1 },
            { "hash_type" => 7900, "runtime" => 4294967295, "hash_speed" => 4902, "device" => 1 },
            { "hash_type" => 8000, "runtime" => 4294967295, "hash_speed" => 57820567, "device" => 1 },
            { "hash_type" => 8100, "runtime" => 4294967295, "hash_speed" => 1193067681, "device" => 1 },
            { "hash_type" => 8200, "runtime" => 4294967295, "hash_speed" => 740, "device" => 1 },
            { "hash_type" => 8300, "runtime" => 4294967295, "hash_speed" => 356514503, "device" => 1 },
            { "hash_type" => 8400, "runtime" => 4294967295, "hash_speed" => 144618705, "device" => 1 },
            { "hash_type" => 8500, "runtime" => 4294967295, "hash_speed" => 656873889, "device" => 1 },
            { "hash_type" => 8600, "runtime" => 4294967295, "hash_speed" => 74867536, "device" => 1 },
            { "hash_type" => 8700, "runtime" => 4294967295, "hash_speed" => 15201820, "device" => 1 },
            { "hash_type" => 8800, "runtime" => 4294967295, "hash_speed" => 136999, "device" => 1 },
            { "hash_type" => 9000, "runtime" => 4294967295, "hash_speed" => 55572, "device" => 1 },
            { "hash_type" => 9100, "runtime" => 4294967295, "hash_speed" => 110666, "device" => 1 },
            { "hash_type" => 9200, "runtime" => 4294967295, "hash_speed" => 10790, "device" => 1 },
            { "hash_type" => 9400, "runtime" => 4294967295, "hash_speed" => 23023, "device" => 1 },
            { "hash_type" => 9500, "runtime" => 4294967295, "hash_speed" => 11510, "device" => 1 },
            { "hash_type" => 9600, "runtime" => 4294967295, "hash_speed" => 968, "device" => 1 },
            { "hash_type" => 9700, "runtime" => 4294967295, "hash_speed" => 42365851, "device" => 1 },
            { "hash_type" => 9710, "runtime" => 4294967295, "hash_speed" => 61259332, "device" => 1 },
            { "hash_type" => 9720, "runtime" => 4294967295, "hash_speed" => 298081444, "device" => 1 },
            { "hash_type" => 9800, "runtime" => 4294967295, "hash_speed" => 26603138, "device" => 1 },
            { "hash_type" => 9810, "runtime" => 4294967295, "hash_speed" => 61452302, "device" => 1 },
            { "hash_type" => 9820, "runtime" => 4294967295, "hash_speed" => 448528699, "device" => 1 },
            { "hash_type" => 9900, "runtime" => 4294967295, "hash_speed" => 1266826443, "device" => 1 },
            { "hash_type" => 10000, "runtime" => 4294967295, "hash_speed" => 21566, "device" => 1 },
            { "hash_type" => 10100, "runtime" => 4294967295, "hash_speed" => 3653724101, "device" => 1 },
            { "hash_type" => 10200, "runtime" => 4294967295, "hash_speed" => 578814096, "device" => 1 },
            { "hash_type" => 10300, "runtime" => 4294967295, "hash_speed" => 825458, "device" => 1 },
            { "hash_type" => 10400, "runtime" => 4294967295, "hash_speed" => 63401163, "device" => 1 },
            { "hash_type" => 10410, "runtime" => 4294967295, "hash_speed" => 72142692, "device" => 1 },
            { "hash_type" => 10420, "runtime" => 4294967295, "hash_speed" => 1188945928, "device" => 1 },
            { "hash_type" => 10500, "runtime" => 4294967295, "hash_speed" => 3208852, "device" => 1 },
            { "hash_type" => 10600, "runtime" => 4294967295, "hash_speed" => 535884883, "device" => 1 },
            { "hash_type" => 10800, "runtime" => 4294967295, "hash_speed" => 105291929, "device" => 1 },
            { "hash_type" => 10810, "runtime" => 4294967295, "hash_speed" => 104302190, "device" => 1 },
            { "hash_type" => 10820, "runtime" => 4294967295, "hash_speed" => 99685184, "device" => 1 },
            { "hash_type" => 10830, "runtime" => 4294967295, "hash_speed" => 105142799, "device" => 1 },
            { "hash_type" => 10840, "runtime" => 4294967295, "hash_speed" => 99391090, "device" => 1 },
            { "hash_type" => 10870, "runtime" => 4294967295, "hash_speed" => 105011178, "device" => 1 },
            { "hash_type" => 10900, "runtime" => 4294967295, "hash_speed" => 213614, "device" => 1 },
            { "hash_type" => 10901, "runtime" => 4294967295, "hash_speed" => 26335, "device" => 1 },
            { "hash_type" => 11000, "runtime" => 4294967295, "hash_speed" => 1351257731, "device" => 1 },
            { "hash_type" => 11100, "runtime" => 4294967295, "hash_speed" => 1146611262, "device" => 1 },
            { "hash_type" => 11200, "runtime" => 4294967295, "hash_speed" => 365951205, "device" => 1 },
            { "hash_type" => 11300, "runtime" => 4294967295, "hash_speed" => 483, "device" => 1 },
            { "hash_type" => 11400, "runtime" => 4294967295, "hash_speed" => 367136407, "device" => 1 },
            { "hash_type" => 11500, "runtime" => 4294967295, "hash_speed" => 12028699086, "device" => 1 },
            { "hash_type" => 11600, "runtime" => 4294967295, "hash_speed" => 69417, "device" => 1 },
            { "hash_type" => 11900, "runtime" => 4294967295, "hash_speed" => 1156143, "device" => 1 },
            { "hash_type" => 12000, "runtime" => 4294967295, "hash_speed" => 545710, "device" => 1 },
            { "hash_type" => 12001, "runtime" => 4294967295, "hash_speed" => 55907, "device" => 1 },
            { "hash_type" => 12100, "runtime" => 4294967295, "hash_speed" => 36987, "device" => 1 },
            { "hash_type" => 12200, "runtime" => 4294967295, "hash_speed" => 1480, "device" => 1 },
            { "hash_type" => 12300, "runtime" => 4294967295, "hash_speed" => 8826, "device" => 1 },
            { "hash_type" => 12400, "runtime" => 4294967295, "hash_speed" => 940487, "device" => 1 },
            { "hash_type" => 12500, "runtime" => 4294967295, "hash_speed" => 8565, "device" => 1 },
            { "hash_type" => 12600, "runtime" => 4294967295, "hash_speed" => 314858140, "device" => 1 },
            { "hash_type" => 12700, "runtime" => 4294967295, "hash_speed" => 9885884, "device" => 1 },
            { "hash_type" => 12800, "runtime" => 4294967295, "hash_speed" => 1881920, "device" => 1 },
            { "hash_type" => 12900, "runtime" => 4294967295, "hash_speed" => 52596, "device" => 1 },
            { "hash_type" => 13000, "runtime" => 4294967295, "hash_speed" => 6575, "device" => 1 },
            { "hash_type" => 13100, "runtime" => 4294967295, "hash_speed" => 47898773, "device" => 1 },
            { "hash_type" => 13200, "runtime" => 4294967295, "hash_speed" => 73128, "device" => 1 },
            { "hash_type" => 13300, "runtime" => 4294967295, "hash_speed" => 1350577874, "device" => 1 },
            { "hash_type" => 13400, "runtime" => 4294967295, "hash_speed" => 19765, "device" => 1 },
            { "hash_type" => 13500, "runtime" => 4294967295, "hash_speed" => 931446591, "device" => 1 },
            { "hash_type" => 13600, "runtime" => 4294967295, "hash_speed" => 527130, "device" => 1 },
            { "hash_type" => 13711, "runtime" => 4294967295, "hash_speed" => 139, "device" => 1 },
            { "hash_type" => 13712, "runtime" => 4294967295, "hash_speed" => 78, "device" => 1 },
            { "hash_type" => 13713, "runtime" => 4294967295, "hash_speed" => 54, "device" => 1 },
            { "hash_type" => 13721, "runtime" => 4294967295, "hash_speed" => 70, "device" => 1 },
            { "hash_type" => 13722, "runtime" => 4294967295, "hash_speed" => 29, "device" => 1 },
            { "hash_type" => 13723, "runtime" => 4294967295, "hash_speed" => 19, "device" => 1 },
            { "hash_type" => 13731, "runtime" => 4294967295, "hash_speed" => 18, "device" => 1 },
            { "hash_type" => 13732, "runtime" => 4294967295, "hash_speed" => 8, "device" => 1 },
            { "hash_type" => 13733, "runtime" => 4294967295, "hash_speed" => 5, "device" => 1 },
            { "hash_type" => 13741, "runtime" => 4294967295, "hash_speed" => 275, "device" => 1 },
            { "hash_type" => 13742, "runtime" => 4294967295, "hash_speed" => 157, "device" => 1 },
            { "hash_type" => 13743, "runtime" => 4294967295, "hash_speed" => 108, "device" => 1 },
            { "hash_type" => 13751, "runtime" => 4294967295, "hash_speed" => 207, "device" => 1 },
            { "hash_type" => 13752, "runtime" => 4294967295, "hash_speed" => 104, "device" => 1 },
            { "hash_type" => 13753, "runtime" => 4294967295, "hash_speed" => 68, "device" => 1 },
            { "hash_type" => 13761, "runtime" => 4294967295, "hash_speed" => 521, "device" => 1 },
            { "hash_type" => 13762, "runtime" => 4294967295, "hash_speed" => 261, "device" => 1 },
            { "hash_type" => 13763, "runtime" => 4294967295, "hash_speed" => 174, "device" => 1 },
            { "hash_type" => 13800, "runtime" => 4294967295, "hash_speed" => 112689521, "device" => 1 },
            { "hash_type" => 13900, "runtime" => 4294967295, "hash_speed" => 328488389, "device" => 1 },
            { "hash_type" => 14000, "runtime" => 4294967295, "hash_speed" => 483145169, "device" => 1 },
            { "hash_type" => 14100, "runtime" => 4294967295, "hash_speed" => 645873729, "device" => 1 },
            { "hash_type" => 14400, "runtime" => 4294967295, "hash_speed" => 49909018, "device" => 1 },
            { "hash_type" => 14500, "runtime" => 4294967295, "hash_speed" => 186415582, "device" => 1 },
            { "hash_type" => 14600, "runtime" => 4294967295, "hash_speed" => 1725, "device" => 1 },
            { "hash_type" => 14700, "runtime" => 4294967295, "hash_speed" => 28063, "device" => 1 },
            { "hash_type" => 14800, "runtime" => 4294967295, "hash_speed" => 21, "device" => 1 },
            { "hash_type" => 14900, "runtime" => 4294967295, "hash_speed" => 2051255165, "device" => 1 },
            { "hash_type" => 15000, "runtime" => 4294967295, "hash_speed" => 99340478, "device" => 1 },
            { "hash_type" => 15100, "runtime" => 4294967295, "hash_speed" => 28050, "device" => 1 },
            { "hash_type" => 15200, "runtime" => 4294967295, "hash_speed" => 55862, "device" => 1 },
            { "hash_type" => 15300, "runtime" => 4294967295, "hash_speed" => 11695, "device" => 1 },
            { "hash_type" => 15310, "runtime" => 4294967295, "hash_speed" => 9190, "device" => 1 },
            { "hash_type" => 15400, "runtime" => 4294967295, "hash_speed" => 831842132, "device" => 1 },
            { "hash_type" => 15500, "runtime" => 4294967295, "hash_speed" => 1273606315, "device" => 1 },
            { "hash_type" => 15600, "runtime" => 4294967295, "hash_speed" => 208324, "device" => 1 },
            { "hash_type" => 15900, "runtime" => 4294967295, "hash_speed" => 3202, "device" => 1 },
            { "hash_type" => 15910, "runtime" => 4294967295, "hash_speed" => 9195, "device" => 1 },
            { "hash_type" => 16000, "runtime" => 4294967295, "hash_speed" => 66708612, "device" => 1 },
            { "hash_type" => 16100, "runtime" => 4294967295, "hash_speed" => 2236738459, "device" => 1 },
            { "hash_type" => 16200, "runtime" => 4294967295, "hash_speed" => 10799, "device" => 1 },
            { "hash_type" => 16300, "runtime" => 4294967295, "hash_speed" => 105463, "device" => 1 },
            { "hash_type" => 16400, "runtime" => 4294967295, "hash_speed" => 3567864960, "device" => 1 },
            { "hash_type" => 16500, "runtime" => 4294967295, "hash_speed" => 98253721, "device" => 1 },
            { "hash_type" => 16600, "runtime" => 4294967295, "hash_speed" => 85194670, "device" => 1 },
            { "hash_type" => 16700, "runtime" => 4294967295, "hash_speed" => 10791, "device" => 1 },
            { "hash_type" => 16900, "runtime" => 4294967295, "hash_speed" => 21577, "device" => 1 },
            { "hash_type" => 17010, "runtime" => 4294967295, "hash_speed" => 492518, "device" => 1 },
            { "hash_type" => 17210, "runtime" => 4294967295, "hash_speed" => 288516182, "device" => 1 },
            { "hash_type" => 17230, "runtime" => 4294967295, "hash_speed" => 1825594776, "device" => 1 },
            { "hash_type" => 17300, "runtime" => 4294967295, "hash_speed" => 109198229, "device" => 1 },
            { "hash_type" => 17400, "runtime" => 4294967295, "hash_speed" => 110411287, "device" => 1 },
            { "hash_type" => 17500, "runtime" => 4294967295, "hash_speed" => 109646406, "device" => 1 },
            { "hash_type" => 17600, "runtime" => 4294967295, "hash_speed" => 108265248, "device" => 1 },
            { "hash_type" => 17700, "runtime" => 4294967295, "hash_speed" => 109218133, "device" => 1 },
            { "hash_type" => 17800, "runtime" => 4294967295, "hash_speed" => 110293700, "device" => 1 },
            { "hash_type" => 17900, "runtime" => 4294967295, "hash_speed" => 110104058, "device" => 1 },
            { "hash_type" => 18000, "runtime" => 4294967295, "hash_speed" => 108139638, "device" => 1 },
            { "hash_type" => 18100, "runtime" => 4294967295, "hash_speed" => 239100672, "device" => 1 },
            { "hash_type" => 18200, "runtime" => 4294967295, "hash_speed" => 47363830, "device" => 1 },
            { "hash_type" => 18300, "runtime" => 4294967295, "hash_speed" => 10789, "device" => 1 },
            { "hash_type" => 18400, "runtime" => 4294967295, "hash_speed" => 2807, "device" => 1 },
            { "hash_type" => 18500, "runtime" => 4294967295, "hash_speed" => 479376421, "device" => 1 },
            { "hash_type" => 18600, "runtime" => 4294967295, "hash_speed" => 245797, "device" => 1 },
            { "hash_type" => 18700, "runtime" => 4294967295, "hash_speed" => 13034010973, "device" => 1 },
            { "hash_type" => 18800, "runtime" => 4294967295, "hash_speed" => 46930, "device" => 1 },
            { "hash_type" => 18900, "runtime" => 4294967295, "hash_speed" => 28061, "device" => 1 },
            { "hash_type" => 19000, "runtime" => 4294967295, "hash_speed" => 1315218, "device" => 1 },
            { "hash_type" => 19100, "runtime" => 4294967295, "hash_speed" => 1037442, "device" => 1 },
            { "hash_type" => 19300, "runtime" => 4294967295, "hash_speed" => 119856091, "device" => 1 },
            { "hash_type" => 19500, "runtime" => 4294967295, "hash_speed" => 20111164, "device" => 1 },
            { "hash_type" => 19600, "runtime" => 4294967295, "hash_speed" => 135074, "device" => 1 },
            { "hash_type" => 19700, "runtime" => 4294967295, "hash_speed" => 68169, "device" => 1 },
            { "hash_type" => 19800, "runtime" => 4294967295, "hash_speed" => 135149, "device" => 1 },
            { "hash_type" => 19900, "runtime" => 4294967295, "hash_speed" => 68032, "device" => 1 },
            { "hash_type" => 20011, "runtime" => 4294967295, "hash_speed" => 36216, "device" => 1 },
            { "hash_type" => 20012, "runtime" => 4294967295, "hash_speed" => 18254, "device" => 1 },
            { "hash_type" => 20013, "runtime" => 4294967295, "hash_speed" => 9999, "device" => 1 },
            { "hash_type" => 20200, "runtime" => 4294967295, "hash_speed" => 1173, "device" => 1 },
            { "hash_type" => 20300, "runtime" => 4294967295, "hash_speed" => 7439, "device" => 1 },
            { "hash_type" => 20400, "runtime" => 4294967295, "hash_speed" => 4276, "device" => 1 },
            { "hash_type" => 20500, "runtime" => 4294967295, "hash_speed" => 14245142008, "device" => 1 },
            { "hash_type" => 20510, "runtime" => 4294967295, "hash_speed" => 2148858917, "device" => 1 },
            { "hash_type" => 20600, "runtime" => 4294967295, "hash_speed" => 463120, "device" => 1 },
            { "hash_type" => 20710, "runtime" => 4294967295, "hash_speed" => 130555896, "device" => 1 },
            { "hash_type" => 20711, "runtime" => 4294967295, "hash_speed" => 130657570, "device" => 1 },
            { "hash_type" => 20720, "runtime" => 4294967295, "hash_speed" => 80777752, "device" => 1 },
            { "hash_type" => 20800, "runtime" => 4294967295, "hash_speed" => 408517866, "device" => 1 },
            { "hash_type" => 20900, "runtime" => 4294967295, "hash_speed" => 421188863, "device" => 1 },
            { "hash_type" => 21000, "runtime" => 4294967295, "hash_speed" => 47200729, "device" => 1 },
            { "hash_type" => 21100, "runtime" => 4294967295, "hash_speed" => 767484720, "device" => 1 },
            { "hash_type" => 21200, "runtime" => 4294967295, "hash_speed" => 830987196, "device" => 1 },
            { "hash_type" => 21300, "runtime" => 4294967295, "hash_speed" => 289731910, "device" => 1 },
            { "hash_type" => 21400, "runtime" => 4294967295, "hash_speed" => 229438288, "device" => 1 },
            { "hash_type" => 21420, "runtime" => 4294967295, "hash_speed" => 121154378, "device" => 1 },
            { "hash_type" => 21500, "runtime" => 4294967295, "hash_speed" => 10393, "device" => 1 },
            { "hash_type" => 21501, "runtime" => 4294967295, "hash_speed" => 10402, "device" => 1 },
            { "hash_type" => 21700, "runtime" => 4294967295, "hash_speed" => 22201, "device" => 1 },
            { "hash_type" => 22000, "runtime" => 4294967295, "hash_speed" => 66844, "device" => 1 },
            { "hash_type" => 22001, "runtime" => 4294967295, "hash_speed" => 42979710, "device" => 1 },
            { "hash_type" => 22100, "runtime" => 4294967295, "hash_speed" => 5, "device" => 1 },
            { "hash_type" => 22200, "runtime" => 4294967295, "hash_speed" => 106021182, "device" => 1 },
            { "hash_type" => 22300, "runtime" => 4294967295, "hash_speed" => 436174030, "device" => 1 },
            { "hash_type" => 22301, "runtime" => 4294967295, "hash_speed" => 439954266, "device" => 1 },
            { "hash_type" => 22400, "runtime" => 4294967295, "hash_speed" => 52511, "device" => 1 },
            { "hash_type" => 22500, "runtime" => 4294967295, "hash_speed" => 73046046, "device" => 1 },
            { "hash_type" => 22600, "runtime" => 4294967295, "hash_speed" => 19707, "device" => 1 },
            { "hash_type" => 22911, "runtime" => 4294967295, "hash_speed" => 46517062, "device" => 1 },
            { "hash_type" => 22921, "runtime" => 4294967295, "hash_speed" => 311514120, "device" => 1 },
            { "hash_type" => 22931, "runtime" => 4294967295, "hash_speed" => 245169820, "device" => 1 },
            { "hash_type" => 22941, "runtime" => 4294967295, "hash_speed" => 129320116, "device" => 1 },
            { "hash_type" => 22951, "runtime" => 4294967295, "hash_speed" => 112258223, "device" => 1 },
            { "hash_type" => 23001, "runtime" => 4294967295, "hash_speed" => 96482885, "device" => 1 },
            { "hash_type" => 23002, "runtime" => 4294967295, "hash_speed" => 63191972, "device" => 1 },
            { "hash_type" => 23003, "runtime" => 4294967295, "hash_speed" => 39773778, "device" => 1 },
            { "hash_type" => 23100, "runtime" => 4294967295, "hash_speed" => 276973, "device" => 1 },
            { "hash_type" => 23200, "runtime" => 4294967295, "hash_speed" => 136048, "device" => 1 },
            { "hash_type" => 23300, "runtime" => 4294967295, "hash_speed" => 138428, "device" => 1 },
            { "hash_type" => 23400, "runtime" => 4294967295, "hash_speed" => 2157, "device" => 1 },
            { "hash_type" => 23500, "runtime" => 4294967295, "hash_speed" => 4588, "device" => 1 },
            { "hash_type" => 23600, "runtime" => 4294967295, "hash_speed" => 1741, "device" => 1 },
            { "hash_type" => 23700, "runtime" => 4294967295, "hash_speed" => 8454, "device" => 1 },
            { "hash_type" => 23900, "runtime" => 4294967295, "hash_speed" => 365278, "device" => 1 },
            { "hash_type" => 24100, "runtime" => 4294967295, "hash_speed" => 55949, "device" => 1 },
            { "hash_type" => 24200, "runtime" => 4294967295, "hash_speed" => 14402, "device" => 1 },
            { "hash_type" => 24300, "runtime" => 4294967295, "hash_speed" => 430610115, "device" => 1 },
            { "hash_type" => 24410, "runtime" => 4294967295, "hash_speed" => 134833, "device" => 1 },
            { "hash_type" => 24420, "runtime" => 4294967295, "hash_speed" => 104260, "device" => 1 },
            { "hash_type" => 24500, "runtime" => 4294967295, "hash_speed" => 119, "device" => 1 },
            { "hash_type" => 24600, "runtime" => 4294967295, "hash_speed" => 4384, "device" => 1 },
            { "hash_type" => 24700, "runtime" => 4294967295, "hash_speed" => 1255756142, "device" => 1 },
            { "hash_type" => 24800, "runtime" => 4294967295, "hash_speed" => 119453300, "device" => 1 },
            { "hash_type" => 24900, "runtime" => 4294967295, "hash_speed" => 2441742977, "device" => 1 },
            { "hash_type" => 25000, "runtime" => 4294967295, "hash_speed" => 39181, "device" => 1 },
            { "hash_type" => 25100, "runtime" => 4294967295, "hash_speed" => 115111, "device" => 1 },
            { "hash_type" => 25200, "runtime" => 4294967295, "hash_speed" => 61941, "device" => 1 },
            { "hash_type" => 25300, "runtime" => 4294967295, "hash_speed" => 985, "device" => 1 },
            { "hash_type" => 25400, "runtime" => 4294967295, "hash_speed" => 3164156, "device" => 1 },
            { "hash_type" => 25500, "runtime" => 4294967295, "hash_speed" => 52695, "device" => 1 },
            { "hash_type" => 25600, "runtime" => 4294967295, "hash_speed" => 2126, "device" => 1 },
            { "hash_type" => 25700, "runtime" => 4294967295, "hash_speed" => 18964672436, "device" => 1 },
            { "hash_type" => 25800, "runtime" => 4294967295, "hash_speed" => 2124, "device" => 1 },
            { "hash_type" => 25900, "runtime" => 4294967295, "hash_speed" => 3290, "device" => 1 },
            { "hash_type" => 26000, "runtime" => 4294967295, "hash_speed" => 24206193, "device" => 1 },
            { "hash_type" => 26100, "runtime" => 4294967295, "hash_speed" => 21608, "device" => 1 },
            { "hash_type" => 26200, "runtime" => 4294967295, "hash_speed" => 93877457, "device" => 1 },
            { "hash_type" => 26300, "runtime" => 4294967295, "hash_speed" => 320224767, "device" => 1 },
            { "hash_type" => 26401, "runtime" => 4294967295, "hash_speed" => 1456402964, "device" => 1 },
            { "hash_type" => 26402, "runtime" => 4294967295, "hash_speed" => 1260497069, "device" => 1 },
            { "hash_type" => 26403, "runtime" => 4294967295, "hash_speed" => 1025847075, "device" => 1 },
            { "hash_type" => 26500, "runtime" => 4294967295, "hash_speed" => 15482, "device" => 1 },
            { "hash_type" => 26600, "runtime" => 4294967295, "hash_speed" => 21565, "device" => 1 },
            { "hash_type" => 26700, "runtime" => 4294967295, "hash_speed" => 25135, "device" => 1 },
            { "hash_type" => 26800, "runtime" => 4294967295, "hash_speed" => 25248, "device" => 1 },
            { "hash_type" => 26900, "runtime" => 4294967295, "hash_speed" => 9069, "device" => 1 },
            { "hash_type" => 27000, "runtime" => 4294967295, "hash_speed" => 34879286, "device" => 1 },
            { "hash_type" => 27100, "runtime" => 4294967295, "hash_speed" => 36145329, "device" => 1 },
            { "hash_type" => 27200, "runtime" => 4294967295, "hash_speed" => 1309441248, "device" => 1 },
            { "hash_type" => 27300, "runtime" => 4294967295, "hash_speed" => 9059, "device" => 1 },
            { "hash_type" => 27400, "runtime" => 4294967295, "hash_speed" => 28071, "device" => 1 },
            { "hash_type" => 27500, "runtime" => 4294967295, "hash_speed" => 770, "device" => 1 },
            { "hash_type" => 27600, "runtime" => 4294967295, "hash_speed" => 598, "device" => 1 },
            { "hash_type" => 27800, "runtime" => 4294967295, "hash_speed" => 15556966444, "device" => 1 },
            { "hash_type" => 27900, "runtime" => 4294967295, "hash_speed" => 12053544796, "device" => 1 },
            { "hash_type" => 28000, "runtime" => 4294967295, "hash_speed" => 8451997984, "device" => 1 },
            { "hash_type" => 28100, "runtime" => 4294967295, "hash_speed" => 21571, "device" => 1 },
            { "hash_type" => 28300, "runtime" => 4294967295, "hash_speed" => 223588890, "device" => 1 },
            { "hash_type" => 28400, "runtime" => 4294967295, "hash_speed" => 17, "device" => 1 },
            { "hash_type" => 28600, "runtime" => 4294967295, "hash_speed" => 52567, "device" => 1 },
            { "hash_type" => 28700, "runtime" => 4294967295, "hash_speed" => 16611631, "device" => 1 },
            { "hash_type" => 28800, "runtime" => 4294967295, "hash_speed" => 136011, "device" => 1 },
            { "hash_type" => 28900, "runtime" => 4294967295, "hash_speed" => 68324, "device" => 1 },
            { "hash_type" => 29000, "runtime" => 4294967295, "hash_speed" => 253735061, "device" => 1 },
            { "hash_type" => 29100, "runtime" => 4294967295, "hash_speed" => 109752564, "device" => 1 },
            { "hash_type" => 29200, "runtime" => 4294967295, "hash_speed" => 122870, "device" => 1 },
            { "hash_type" => 29311, "runtime" => 4294967295, "hash_speed" => 46054, "device" => 1 },
            { "hash_type" => 29312, "runtime" => 4294967295, "hash_speed" => 25782, "device" => 1 },
            { "hash_type" => 29313, "runtime" => 4294967295, "hash_speed" => 17895, "device" => 1 },
            { "hash_type" => 29321, "runtime" => 4294967295, "hash_speed" => 33368, "device" => 1 },
            { "hash_type" => 29322, "runtime" => 4294967295, "hash_speed" => 18786, "device" => 1 },
            { "hash_type" => 29323, "runtime" => 4294967295, "hash_speed" => 12027, "device" => 1 },
            { "hash_type" => 29331, "runtime" => 4294967295, "hash_speed" => 9285, "device" => 1 },
            { "hash_type" => 29332, "runtime" => 4294967295, "hash_speed" => 4848, "device" => 1 },
            { "hash_type" => 29333, "runtime" => 4294967295, "hash_speed" => 3232, "device" => 1 },
            { "hash_type" => 29341, "runtime" => 4294967295, "hash_speed" => 91084, "device" => 1 },
            { "hash_type" => 29342, "runtime" => 4294967295, "hash_speed" => 51559, "device" => 1 },
            { "hash_type" => 29343, "runtime" => 4294967295, "hash_speed" => 35168, "device" => 1 },
            { "hash_type" => 29411, "runtime" => 4294967295, "hash_speed" => 140, "device" => 1 },
            { "hash_type" => 29412, "runtime" => 4294967295, "hash_speed" => 79, "device" => 1 },
            { "hash_type" => 29413, "runtime" => 4294967295, "hash_speed" => 54, "device" => 1 },
            { "hash_type" => 29421, "runtime" => 4294967295, "hash_speed" => 71, "device" => 1 },
            { "hash_type" => 29422, "runtime" => 4294967295, "hash_speed" => 35, "device" => 1 },
            { "hash_type" => 29423, "runtime" => 4294967295, "hash_speed" => 23, "device" => 1 },
            { "hash_type" => 29431, "runtime" => 4294967295, "hash_speed" => 18, "device" => 1 },
            { "hash_type" => 29432, "runtime" => 4294967295, "hash_speed" => 10, "device" => 1 },
            { "hash_type" => 29433, "runtime" => 4294967295, "hash_speed" => 6, "device" => 1 },
            { "hash_type" => 29441, "runtime" => 4294967295, "hash_speed" => 275, "device" => 1 },
            { "hash_type" => 29442, "runtime" => 4294967295, "hash_speed" => 157, "device" => 1 },
            { "hash_type" => 29443, "runtime" => 4294967295, "hash_speed" => 108, "device" => 1 },
            { "hash_type" => 29451, "runtime" => 4294967295, "hash_speed" => 206, "device" => 1 },
            { "hash_type" => 29452, "runtime" => 4294967295, "hash_speed" => 102, "device" => 1 },
            { "hash_type" => 29453, "runtime" => 4294967295, "hash_speed" => 66, "device" => 1 },
            { "hash_type" => 29461, "runtime" => 4294967295, "hash_speed" => 505, "device" => 1 },
            { "hash_type" => 29462, "runtime" => 4294967295, "hash_speed" => 239, "device" => 1 },
            { "hash_type" => 29463, "runtime" => 4294967295, "hash_speed" => 171, "device" => 1 },
            { "hash_type" => 29511, "runtime" => 4294967295, "hash_speed" => 3724, "device" => 1 },
            { "hash_type" => 29512, "runtime" => 4294967295, "hash_speed" => 180539944, "device" => 1 },
            { "hash_type" => 29513, "runtime" => 4294967295, "hash_speed" => 1856, "device" => 1 },
            { "hash_type" => 29521, "runtime" => 4294967295, "hash_speed" => 2348, "device" => 1 },
            { "hash_type" => 29522, "runtime" => 4294967295, "hash_speed" => 1084, "device" => 1 },
            { "hash_type" => 29523, "runtime" => 4294967295, "hash_speed" => 2314, "device" => 1 },
            { "hash_type" => 29531, "runtime" => 4294967295, "hash_speed" => 477, "device" => 1 },
            { "hash_type" => 29532, "runtime" => 4294967295, "hash_speed" => 320959902, "device" => 1 }
          ] }
        }

        run_test! do
          expect(response).to have_http_status(:no_content)
          expect(agent.reload.hashcat_benchmarks.count).to eq(418)
        end
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
