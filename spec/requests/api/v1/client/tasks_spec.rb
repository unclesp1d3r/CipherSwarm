# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "api/v1/client/tasks" do
  path "/api/v1/client/tasks/new" do
    get("new task") do
      tags "Tasks"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "newTask"

      let!(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(204, "no new task available") do
        run_test! do
          expect(response).to have_http_status(:no_content)
        end
      end

      ## TODO: Fix this test
      # response(200, 'new task available') do
      #   let(:project) { create(:project) }
      #   let(:hash_list) { create(:hash_list, project: project) }
      #   let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
      #   let(:agent) { create(:agent) }
      #   let(:attack) { create(:attack) }
      #
      #   run_test! do
      #     expect(response).to have_http_status(:ok)
      #   end
      # end
    end
  end

  path "/api/v1/client/tasks/{id}" do
    parameter name: "id", in: :path, type: :string, description: "id"

    get("show task") do
      tags "Tasks"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "showTask"

      let!(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:task) { create(:task, agent: agent, attack: attack) }

      response(200, "successful") do
        let(:id) { task.id }

        schema "$ref" => "#/components/schemas/task"

        after do |example|
          example.metadata[:response][:content] = {
            "application/json" => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test!
      end
    end
  end

  path "/api/v1/client/tasks/{id}/submit_crack" do
    parameter name: "id", in: :path, type: :string, description: "id"

    post("submit_crack task") do
      tags "Tasks"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "submitCrack"
      parameter name: :hashcat_result, in: :body, schema: { "$ref" => "#/components/schemas/hashcat_result" }

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(200, "successful") do
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
            plaintext: "plaintext"
          }
        end

        after do |example|
          example.metadata[:response][:content] = {
            "application/json" => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test!
      end

      response(204, "No more uncracked hashes") do
        let(:hash_list) do
          hash_list = create(:hash_list, name: "completed hashes")
          hash_list.hash_items.delete_all
          hash_item = create(:hash_item, plain_text: "dummy_text", cracked: true, hash_value: "dummy_hash")
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
            hash: "dummy_hash",
            plaintext: "dummy_plain"
          }
        end

        run_test! do
          expect(response).to have_http_status(:no_content)
        end
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
            plaintext: "dummy_plain"
          }
        end

        run_test! do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  path "/api/v1/client/tasks/{id}/submit_status" do
    parameter name: "id", in: :path, type: :string, description: "id"

    post("submit_status task") do
      tags "Tasks"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "submitStatus"

      parameter name: :hashcat_status, in: :body, description: "status",
                schema: { "$ref" => "#/components/schemas/task_status" }

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:task) { create(:task, agent: agent, attack: create(:dictionary_attack)) }

      response(204, "task received successfully") do
        let(:id) { task.id }
        let(:hashcat_status) { create(:hashcat_status, task: task) }

        run_test!
      end
    end
  end

  path "/api/v1/client/tasks/{id}/accept_task" do
    parameter name: "id", in: :path, type: :string, description: "id"

    post("accept_task task") do
      tags "Tasks"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "acceptTask"

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

        schema "$ref" => "#/components/schemas/error_object"

        after do |example|
          example.metadata[:response][:content] = {
            "application/json" => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test! do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({ error: "Task already completed" })
        end
      end

      response(404, "task not found for agent") do
        let(:task) { create(:task, agent: agent, state: "completed", attack: create(:dictionary_attack)) }
        let(:id) { 123 }

        schema "$ref" => "#/components/schemas/error_object"

        after do |example|
          example.metadata[:response][:content] = {
            "application/json" => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test! do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  path "/api/v1/client/tasks/{id}/exhausted" do
    parameter name: "id", in: :path, type: :string, description: "id"

    post("exhausted task") do
      tags "Tasks"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "exhaustedTask"

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(204, "successful") do
        let(:task) { create(:task, agent: agent, state: "running", attack: create(:dictionary_attack)) }
        let(:id) { task.id }

        run_test! do
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
