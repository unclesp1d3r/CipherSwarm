# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "api/v1/client/attacks" do
  path "/api/v1/client/attacks/{id}" do
    parameter name: :id, in: :path, type: :string, description: "id"

    get("show attack") do
      tags "Attacks"
      security [bearer_auth: []]
      consumes "application/json"
      produces "application/json"
      operationId "showAttack"

      let(:agent) { create(:agent) }
      let(:attack) { create(:dictionary_attack) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
      let(:id) { attack.id }

      response(200, "successful") do
        schema "$ref" => "#/components/schemas/attack"

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

        schema "$ref" => "#/components/schemas/error_object"
        run_test!
      end

      response 401, "unauthorized" do
        let(:Authorization) { "Bearer invalid" } # rubocop:disable RSpec/VariableName

        schema "$ref" => "#/components/schemas/error_object"
        run_test!
      end
    end
  end

  path "/api/v1/client/attacks/{id}/hash_list" do
    parameter name: "id", in: :path, type: :string, description: "id"

    get("hash_list attack") do
      tags "Attacks"
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

        run_test!
      end

      response 404, "not found" do
        let(:id) { 655_555 }

        schema "$ref" => "#/components/schemas/error_object"
        run_test!
      end
    end
  end
end
