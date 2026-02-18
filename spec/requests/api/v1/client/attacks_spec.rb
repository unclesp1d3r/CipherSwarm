# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "swagger_helper"

RSpec.describe "api/v1/client/attacks" do
  path "/api/v1/client/attacks/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    get("show attack") do
      tags "Attacks"
      description "Returns an attack by id. This is used to get the details of an attack."
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "getAttack"

      let(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:id) { attack.id }

      before { create(:task, attack: attack, agent: agent) }

      response(200, "successful") do
        schema "$ref" => "#/components/schemas/Attack"

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

      response 404, "not found" do
        let(:id) { 655_555 }

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

      response 401, "unauthorized" do
        let(:Authorization) { "Bearer invalid" } # rubocop:disable RSpec/VariableName

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

  path "/api/v1/client/attacks/{id}/hash_list" do
    parameter name: "id", in: :path, schema: { type: :integer, format: "int64" }, required: true, description: "id"

    get("Get the hash list") do
      tags "Attacks"
      description "Returns the hash list for an attack."
      security [bearer_auth: []]
      consumes "application/json"
      produces "text/plain"
      operationId "getHashList"

      let(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:id) { attack.id }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      before { create(:task, attack: attack, agent: agent) }

      response(200, "successful") do
        schema type: :string, format: :binary

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

        run_test!
      end

      response 404, "not found" do
        let(:id) { 655_555 }

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

  describe "attack scoping to agent" do
    let(:agent) { create(:agent) }
    let(:other_agent) { create(:agent) }
    let(:attack) { create(:dictionary_attack) }

    before { create(:task, attack: attack, agent: other_agent) }

    it "returns 404 when agent has no task for the attack" do
      get "/api/v1/client/attacks/#{attack.id}",
          headers: { "Authorization" => "Bearer #{agent.token}", "Accept" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for hash_list when agent has no task for the attack" do
      get "/api/v1/client/attacks/#{attack.id}/hash_list",
          headers: { "Authorization" => "Bearer #{agent.token}", "Accept" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end

    context "when the attack's campaign has no hash_list" do
      let(:assigned_agent) { create(:agent) }
      let(:assigned_attack) { create(:dictionary_attack) }

      before do
        create(:task, attack: assigned_attack, agent: assigned_agent)
        allow_any_instance_of(Campaign).to receive(:hash_list).and_return(nil) # rubocop:disable RSpec/AnyInstance
      end

      it "returns 404 with hash list not found error" do
        get "/api/v1/client/attacks/#{assigned_attack.id}/hash_list",
            headers: { "Authorization" => "Bearer #{assigned_agent.token}", "Accept" => "application/json" }

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["error"]).to eq("Hash list not found.")
      end
    end

    it "returns 422 when a NoMethodError occurs" do
      create(:task, attack: attack, agent: agent)
      allow(Attack).to receive(:joins).and_raise(NoMethodError.new("undefined method"))

      get "/api/v1/client/attacks/#{attack.id}",
          headers: { "Authorization" => "Bearer #{agent.token}", "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("Invalid request")
    end

    context "when the attack's campaign association is nil" do
      let(:assigned_agent) { create(:agent) }
      let(:assigned_attack) { create(:dictionary_attack) }

      before do
        create(:task, attack: assigned_attack, agent: assigned_agent)
        allow_any_instance_of(Attack).to receive(:campaign).and_return(nil) # rubocop:disable RSpec/AnyInstance
      end

      it "returns 404 when campaign is nil" do
        get "/api/v1/client/attacks/#{assigned_attack.id}/hash_list",
            headers: { "Authorization" => "Bearer #{assigned_agent.token}", "Accept" => "application/json" }

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["error"]).to eq("Hash list not found.")
      end
    end

    context "when @agent is nil during NoMethodError" do
      before do
        allow_any_instance_of(Api::V1::Client::AttacksController).to receive(:authenticate_agent) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Api::V1::Client::AttacksController).to receive(:update_last_seen) # rubocop:disable RSpec/AnyInstance
        allow(Attack).to receive(:joins).and_raise(NoMethodError.new("undefined method"))
        allow(Rails.logger).to receive(:error)
      end

      it "logs with 'unknown' agent identifier" do
        get "/api/v1/client/attacks/#{attack.id}",
            headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Rails.logger).to have_received(:error).with(/unknown/)
      end
    end

    context "when @agent is nil during hash_list ATTACK_NOT_FOUND" do
      before do
        allow_any_instance_of(Api::V1::Client::AttacksController).to receive(:authenticate_agent) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Api::V1::Client::AttacksController).to receive(:update_last_seen) # rubocop:disable RSpec/AnyInstance
        allow(Rails.logger).to receive(:error)
      end

      it "logs with 'unknown' agent identifier" do
        get "/api/v1/client/attacks/999999/hash_list",
            headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:not_found)
        expect(Rails.logger).to have_received(:error).with(/ATTACK_NOT_FOUND.*unknown/)
      end
    end

    context "when @agent is nil during hash_list HASH_LIST_NOT_FOUND" do
      let(:test_attack) { create(:dictionary_attack) }

      before do
        allow_any_instance_of(Api::V1::Client::AttacksController).to receive(:authenticate_agent) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Api::V1::Client::AttacksController).to receive(:update_last_seen) # rubocop:disable RSpec/AnyInstance
        query_scope = double("attack_scope") # rubocop:disable RSpec/VerifiedDoubles
        allow(Attack).to receive(:joins).and_return(query_scope)
        allow(query_scope).to receive_messages(where: query_scope, find_by: test_attack)
        allow(test_attack).to receive(:campaign).and_return(nil)
        allow(Rails.logger).to receive(:error)
      end

      it "logs with 'unknown' agent identifier" do
        get "/api/v1/client/attacks/#{test_attack.id}/hash_list",
            headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:not_found)
        expect(Rails.logger).to have_received(:error).with(/HASH_LIST_NOT_FOUND.*unknown/)
      end
    end
  end
end
