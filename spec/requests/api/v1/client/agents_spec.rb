# rubocop:disable RSpec/NestedGroups
require 'swagger_helper'

RSpec.describe 'api/v1/client/agents' do
  path '/api/v1/client/agents/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'id'

    get "Gets an instance of an agent" do
      tags "Agents"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'showAgent'

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(200, 'successful') do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema '$ref' => '#/components/schemas/agent'

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

      response 401, 'Not authorized' do
        let(:agent) { create(:agent) }
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

        schema '$ref' => '#/components/schemas/error_object'
        run_test!
      end
    end

    put "Updates the agent" do
      tags "Agents"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'updateAgent'

      parameter name: :agent, in: :body, schema:
        { '$ref' => '#/components/schemas/agent' }
      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(200, 'successful') do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema '$ref' => '#/components/schemas/agent'
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test! do
          expect(response).to have_http_status(:ok)
        end
      end

      response 401, 'Not authorized' do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

        schema '$ref' => '#/components/schemas/error_object'
        run_test!
      end
    end
  end

  path '/api/v1/client/agents/{id}/heartbeat' do
    parameter name: :id, in: :path, type: :string, description: 'id'

    post "Send a heartbeat for an agent" do
      tags "Agents"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'heartbeatAgent'

      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(204, 'successful') do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        run_test! do
          expect(response).to have_http_status(:no_content)
        end
      end

      response 401, 'Not authorized' do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

        schema '$ref' => '#/components/schemas/error_object'
        run_test!
      end
    end
  end

  path '/api/v1/client/agents/{id}/last_benchmark' do
    parameter name: :id, in: :path, type: :integer, description: 'id'

    get('last_benchmark agent') do
      tags "Agents"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'lastBenchmarkAgent'
      let(:agent) { create(:agent) }
      let(:id) { agent.id }

      response(200, 'successful') do
        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

        schema type: :object,
               properties: {
                 last_benchmark_date: { type: :string, format: :date_time }
               },
               required: [ 'last_benchmark_date' ]
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test!
      end

      response 401, 'Not authorized' do
        let(:Authorization) { "Bearer Invalid" } # rubocop:disable RSpec/VariableName

        schema '$ref' => '#/components/schemas/error_object'
        run_test!
      end
    end
  end

  path '/api/v1/client/agents/{id}/submit_benchmark' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    post('submit_benchmark agent') do
      tags "Agents"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'submitBenchmarkAgent'

      parameter name: :hashcat_benchmarks, in: :body, schema: {
        type: :array,
        items: {
          '$ref' => '#/components/schemas/hashcat_benchmark'
        }
      }
      let(:agent) { create(:agent) }

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: [ 'message' ]

        let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName
        let(:id) { agent.id }
        let(:hashcat_benchmarks) do
          [
            {
              hash_type: 1000,
              runtime: 1000,
              hash_speed: '1000',
              device: 1
            }
          ]
        end

        run_test!
      end
    end
  end
end