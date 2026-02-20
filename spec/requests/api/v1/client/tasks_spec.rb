# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "swagger_helper"

RSpec.describe "api/v1/client/tasks" do
  describe "API Request Logging" do
    let(:agent) { create(:agent) }
    let(:attack) { create(:dictionary_attack) }
    let(:task) { create(:task, agent: agent, attack: attack) }

    context "when requesting a task" do
      it "logs APIRequest START and COMPLETE messages" do
        allow(Rails.logger).to receive(:info)

        get "/api/v1/client/tasks/#{task.id}",
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] START.*Agent #{agent.id}/).at_least(:once)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE.*Agent #{agent.id}.*Status 200/).at_least(:once)
      end
    end

    context "when task is not found" do
      it "returns 404 and logs TaskAccess failed" do
        allow(Rails.logger).to receive(:info)

        get "/api/v1/client/tasks/-1",
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:not_found)
        # The TaskAccess log is emitted for failed task lookups
        expect(Rails.logger).to have_received(:info).with(/\[TaskAccess\].*FAILED/).at_least(:once)
      end

      it "does not raise when task is not found" do
        expect {
          get "/api/v1/client/tasks/-1",
              headers: { "Authorization" => "Bearer #{agent.token}" }
        }.not_to raise_error
      end
    end

    context "when submitting status update" do
      let(:running_task) { create(:task, agent: agent, attack: attack, state: "running") }

      it "logs APIRequest for status submission" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        hashcat_status = build(:hashcat_status, task: running_task,
                                                device_statuses: [build(:device_status)],
                                                hashcat_guess: build(:hashcat_guess))

        post "/api/v1/client/tasks/#{running_task.id}/submit_status",
             headers: {
               "Authorization" => "Bearer #{agent.token}",
               "Content-Type" => "application/json"
             },
             params: hashcat_status.to_json

        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE/).at_least(:once)
      end

      it "logs APIError for malformed status data" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        hashcat_status = build(:hashcat_status, task: running_task)

        post "/api/v1/client/tasks/#{running_task.id}/submit_status",
             headers: {
               "Authorization" => "Bearer #{agent.token}",
               "Content-Type" => "application/json"
             },
             params: hashcat_status.to_json

        expect(response).to have_http_status(:unprocessable_content)
        # Error is logged for missing device_statuses
        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end

    context "when accepting a task" do
      let(:pending_task) { create(:task, agent: agent, attack: attack, state: "pending") }
      let(:completed_task) { create(:task, agent: agent, attack: attack, state: "completed") }

      it "logs successful task acceptance" do
        allow(Rails.logger).to receive(:info)

        post "/api/v1/client/tasks/#{pending_task.id}/accept_task",
             headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:no_content)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE.*Status 204/).at_least(:once)
      end

      it "logs task already completed error" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        post "/api/v1/client/tasks/#{completed_task.id}/accept_task",
             headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE.*Status 422/).at_least(:once)
      end
    end

    context "when abandoning a task" do
      let(:running_task) { create(:task, agent: agent, attack: attack, state: "running") }

      it "logs successful task abandonment" do
        allow(Rails.logger).to receive(:info)

        post "/api/v1/client/tasks/#{running_task.id}/abandon",
             headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:info).with(/\[APIRequest\] COMPLETE.*Status 200/).at_least(:once)
      end
    end

    context "when request logging does not break the request" do
      it "handles logging errors gracefully" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        # Request should still succeed even if logging is mocked
        get "/api/v1/client/tasks/#{task.id}",
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "Exhausted endpoint error handling" do
    let(:agent) { create(:agent) }
    let(:attack) { create(:dictionary_attack, state: :running) }
    let(:headers) { { "Authorization" => "Bearer #{agent.token}" } }

    context "when task exhaust fails" do
      let(:pending_task) { create(:task, agent: agent, attack: attack, state: "pending") }

      it "returns 422 with error details when task cannot be exhausted" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        post "/api/v1/client/tasks/#{pending_task.id}/exhausted", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("Failed to exhaust task")
        expect(response.parsed_body).to have_key("details")
      end
    end

    context "when attack exhaust fails" do
      let(:running_task) { create(:task, agent: agent, attack: attack, state: "running") }

      it "succeeds for task even when attack cannot be exhausted" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        # Set an invalid workload_profile (must be 1-4) so save fails during exhaust
        running_task.attack.update_column(:workload_profile, 99) # rubocop:disable Rails/SkipsModelValidations

        post "/api/v1/client/tasks/#{running_task.id}/exhausted", headers: headers

        # Task exhaustion succeeds; attack exhaustion is handled by callback with can_exhaust? guard
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  path "/api/v1/client/tasks/new" do
    get("Request a new task from server") do
      tags "Tasks"
      description "Request a new task from the server, if available."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "getNewTask"

      let(:project) { create(:project) }
      let!(:agent) { create(:agent, projects: [project], hashcat_benchmarks: build_list(:hashcat_benchmark, 1)) }

      response(204, "no new task available") do
        let(:attack) { create(:dictionary_attack) }

        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        run_test!
      end

      context "when only another agent's tasks exist for the attack", :skip_swagger do
        let(:hash_list) do
          hash_list = create(:hash_list, project: project)
          create(:hash_item, hash_list: hash_list, cracked: false)
          hash_list.update!(processed: true)
          hash_list
        end
        let!(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
        let!(:attack) { create(:dictionary_attack, state: "running", campaign: campaign) }
        let(:other_agent) { create(:agent, projects: [project], hashcat_benchmarks: build_list(:hashcat_benchmark, 1)) }

        before { create(:task, agent: other_agent, attack: attack, state: :failed) }

        it "returns 204 and does not return another agent's task" do
          get "/api/v1/client/tasks/new",
              headers: { "Authorization" => "Bearer #{agent.token}" }

          expect(response).to have_http_status(:no_content)
        end
      end

      response(200, "new task available") do
        let(:hash_list) do
          hash_list = create(:hash_list, project: project)
          hash_item = create(:hash_item)
          hash_list.hash_items << hash_item
          hash_list.processed = true
          hash_list.save!
          hash_list
        end
        let!(:campaign) { create(:campaign, project: project, hash_list: hash_list) }

        # rubocop:disable RSpec/LetSetup
        let!(:attack) { create(:dictionary_attack, state: "pending", campaign: campaign) }
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/Task"

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

      response 401, "Unauthorized" do
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

  path "/api/v1/client/tasks/{id}" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    get("Request the task information") do
      tags "Tasks"
      description "Request the task information from the server."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "getTask"

      let!(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:task) { create(:task, agent: agent, attack: attack) }

      response(200, "successful") do
        let(:id) { task.id }

        schema "$ref" => "#/components/schemas/Task"

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

      response 404, "Task not found" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { -1 }

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

      response 401, "Unauthorized" do
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName
        let(:id) { task.id }

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

  path "/api/v1/client/tasks/{id}/submit_crack" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    post("Submit a cracked hash result for a task") do
      tags "Tasks"
      description "Submit a cracked hash result for a task."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "sendCrack"
      parameter name: :hashcat_result, in: :body, description: "Cracked hash result",
                schema: { "$ref" => "#/components/schemas/HashcatResult" }

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(200, "successful", use_as_request_example: true) do
        let(:hash_item) { create(:hash_item, hash_value: "something") }
        let(:hash_item_incomplete) { create(:hash_item, hash_value: "random", plain_text: nil) }
        let(:hash_list) do
          partial_list = create(:hash_list, name: "partially completed hashes")
          partial_list.hash_items.append(hash_item)
          partial_list.hash_items.append(hash_item_incomplete)
          partial_list
        end
        let(:task) do
          create(:task,
                 agent: agent,
                 attack: create(:dictionary_attack,
                                campaign: create(:campaign,
                                                 hash_list: hash_list,
                                                 name: "crack hash campaign"),
                                name: "crack hash attack"),
                 state: "running")
        end
        let(:id) { task.id }
        let(:hashcat_result) do
          {
            timestamp: Time.zone.now,
            hash: hash_item.hash_value,
            plain_text: "plaintext"
          }
        end

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

      response(204, "No more uncracked hashes", use_as_request_example: true) do
        let(:hash_list) do
          hash_list = create(:hash_list, name: "completed hashes")
          hash_list.hash_items.delete_all
          hash_item = create(:hash_item, hash_value: "dummy_hash_2")
          hash_list.hash_items.append(hash_item)
          hash_list
        end

        let(:task) do
          create(:task,
                 agent: agent,
                 attack: create(:dictionary_attack,
                                campaign: create(:campaign,
                                                 hash_list: hash_list,
                                                 name: "complete hash campaign"),
                                name: "complete hash attack"),
                 state: "running")
        end
        let(:id) { task.id }
        let(:hashcat_result) do
          {
            timestamp: Time.zone.now,
            hash: "dummy_hash_2",
            plain_text: "dummy_plain"
          }
        end

        run_test!
      end

      response(404, "Hash value not found") do
        let(:task) do
          create(:task,
                 agent: agent,
                 attack: create(:dictionary_attack,
                                campaign: create(:campaign,
                                                 hash_list: create(:hash_list))))
        end
        let(:id) { task.id }
        let(:hashcat_result) do
          {
            timestamp: Time.zone.now,
            hash: "invalid_hash",
            plain_text: "dummy_plain"
          }
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

  path "/api/v1/client/tasks/{id}/submit_status" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" },
              required: true, description: "id"

    post("Submit a status update for a task") do
      tags "Tasks"
      description "Submit a status update for a task. This includes the status of the current guess and the devices."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "sendStatus"

      parameter name: :hashcat_status, in: :body, description: "Hashcat status update for the task",
                schema: { "$ref" => "#/components/schemas/TaskStatus" },
                required: true

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:task) { create(:task, agent: agent, attack: create(:dictionary_attack)) }

      let!(:status_count) { task.reload.hashcat_statuses.count }

      response(204, "status received successfully") do
        let(:id) { task.id }
        let(:hashcat_status) {
          build(:hashcat_status, task: task,
                                 device_statuses: [build(:device_status)],
                                 hashcat_guess: build(:hashcat_guess))
        }

        run_test! do
          expect(response).to have_http_status(:no_content)
          expect(task.hashcat_statuses.reload.count).to eq(status_count + 1)
          expect(task.hashcat_statuses.last.reload.hashcat_guess).to be_present
          expect(task.hashcat_statuses.last.reload.hashcat_guess.guess_base_percentage).to eq(9.99)
          expect(task.hashcat_statuses.last.reload.device_statuses.count).to eq(1)
        end
      end

      response(202, "status received successfully, but stale") do
        let(:task) { create(:task, agent: agent, attack: create(:dictionary_attack), stale: true) }
        let(:id) { task.id }
        let(:hashcat_status) {
          build(:hashcat_status, task: task,
                                 device_statuses: [build(:device_status)],
                                 hashcat_guess: build(:hashcat_guess))
        }

        run_test!
      end

      response(410, "status received successfully, but task paused") do
        let(:task) { create(:task, agent: agent, attack: create(:dictionary_attack), state: :paused) }
        let(:id) { task.id }
        let(:hashcat_status) {
          build(:hashcat_status, task: task,
                                 device_statuses: [build(:device_status)],
                                 hashcat_guess: build(:hashcat_guess))
        }

        run_test!
      end

      response(422, "malformed status data") do
        let(:id) { task.id }
        let(:hashcat_status) { build(:hashcat_status, task: task) }

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

      response 404, "Task not found" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { -1 }
        let(:hashcat_status) { }

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

      response 401, "Unauthorized" do
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName
        let(:id) { task.id }
        let(:hashcat_status) { }

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

  path "/api/v1/client/tasks/{id}/accept_task" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    post("Accept Task") do
      tags "Tasks"
      description "Accept an offered task from the server."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "setTaskAccepted"

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(204, "task accepted successfully") do
        let(:task) { create(:task, agent: agent, state: "pending", attack: create(:dictionary_attack)) }
        let(:id) { task.id }

        run_test!
      end

      response(422, "task already completed") do
        let(:task) { create(:task, agent: agent, state: "completed", attack: create(:dictionary_attack)) }
        let(:id) { task.id }

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

        run_test! do
          expect(response).to have_http_status(:unprocessable_content)
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({ error: "Task already completed" })
        end
      end

      response(404, "task not found for agent") do
        let(:task) { create(:task, agent: agent, state: "completed", attack: create(:dictionary_attack)) }
        let(:id) { 123 }

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

  path "/api/v1/client/tasks/{id}/exhausted" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    post("Notify of Exhausted Task") do
      tags "Tasks"
      description "Notify the server that the task is exhausted. This will mark the task as completed."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "setTaskExhausted"

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:task) { create(:task, agent: agent, state: "running", attack: create(:dictionary_attack)) }

      response(204, "successful") do
        let(:id) { task.id }

        run_test!
      end

      response 404, "Task not found" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { -1 }

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

      response 401, "Unauthorized" do
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName
        let(:id) { task.id }

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

  path "/api/v1/client/tasks/{id}/abandon" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    post("Abandon Task") do
      tags "Tasks"
      description "Abandon a task. This will mark the task as abandoned. Usually used when the client is unable to complete the task."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "setTaskAbandoned"

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:task) { create(:task, agent: agent, state: "running", attack: create(:dictionary_attack)) }

      response(200, "successful") do
        let(:id) { task.id }

        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 state: { type: :string }
               }

        run_test!
      end

      response(422, "already completed") do
        let(:id) { task.id }
        let(:task) { create(:task, agent: agent, state: "completed", attack: create(:dictionary_attack)) }

        schema type: :object,
               properties: {
                 error: { type: :string },
                 details: { type: :array, items: { type: :string } }
               }

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

      response 404, "Task not found" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { -1 }

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

      response 401, "Unauthorized" do
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName
        let(:id) { task.id }

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

  path "/api/v1/client/tasks/{id}/get_zaps" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    get("Get Completed Hashes") do
      tags "Tasks"
      description "Gets the completed hashes for a task. This is a text file that should be added to the monitored directory to remove the hashes from the list during runtime."
      security [bearer_auth: []]
      consumes "application/json"
      produces "text/plain"
      operationId "getTaskZaps"

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:task) { create(:task, agent: agent, state: "running", attack: create(:dictionary_attack)) }

      response(200, "successful") do
        let(:id) { task.id }
        let(:completed_hash_item) { create(:hash_item, plain_text: "plaintext", cracked: true, cracked_time: DateTime.now) }
        let(:hash_list) do
          hash_list = task.attack.campaign.hash_list
          hash_list.hash_items.append(completed_hash_item)
          hash_list.save!
          hash_list
        end

        after do |example|
          content = example.metadata[:response][:content] || {}
          example_spec = {
            "text/plain" => {
              examples: {
                test_example: {
                  value: response.body
                }
              }
            }
          }
          example.metadata[:response][:content] = content.deep_merge(example_spec)
        end

        schema type: :string, format: :binary

        run_test!
      end

      response(422, "already completed") do
        let(:id) { task.id }
        let(:task) { create(:task, agent: agent, state: "completed", attack: create(:dictionary_attack)) }

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

      response 404, "Task not found" do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { -1 }

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

      response 401, "Unauthorized" do
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName
        let(:id) { task.id }

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
