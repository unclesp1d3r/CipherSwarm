# frozen_string_literal: true

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
      operationId "showAttack"

      let(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:id) { attack.id }

      response(200, "successful") do
        schema "$ref" => "#/components/schemas/Attack"

        after do |example|
          example.metadata[:response][:content] = {
            "application/json" => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test!
      end

      response 404, "not found" do
        let(:id) { 655_555 }

        schema "$ref" => "#/components/schemas/ErrorObject"
        run_test!
      end

      response 401, "unauthorized" do
        let(:Authorization) { "Bearer invalid" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/ErrorObject"
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
      operationId "hashListAttack"

      let(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:id) { attack.id }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(200, "successful") do
        after do |example|
          example.metadata[:response][:content] = {
            "text/plain" => {
              example: response.body
            }
          }
        end

        schema type: :string, format: :binary

        run_test!
      end

      response 404, "not found" do
        let(:id) { 655_555 }

        schema "$ref" => "#/components/schemas/ErrorObject"
        run_test!
      end
    end
  end
end
