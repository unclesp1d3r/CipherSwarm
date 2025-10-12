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
end
