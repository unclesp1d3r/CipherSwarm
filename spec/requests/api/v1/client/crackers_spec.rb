# rubocop:disable RSpec/NestedGroups

require 'swagger_helper'

RSpec.describe 'api/v1/client/crackers' do
  path '/api/v1/client/crackers/check_for_cracker_update' do
    get('check_for_cracker_update cracker') do
      tags "Crackers"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'checkForCrackerUpdate'

      parameter name: :operating_system, in: :query, type: :string, description: 'operating_system'
      parameter name: :version, in: :query, type: :string, description: 'version'

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      before do
        cracker = create(:cracker, name: "hashcat")
        create(:cracker_binary, version: "7.0.0", cracker: cracker,
               operating_systems: [ create(:operating_system,
                                          name: "windows",
                                          cracker_command: "hashcat.exe") ])
      end

      response(200, 'update available') do
        let(:operating_system) { 'windows' }
        let(:version) { '1.0.0' }

        schema '$ref' => '#/components/schemas/cracker_update'

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test! do |response| # rubocop:disable RSpec/MultipleExpectations
          data = JSON.parse(response.body, symbolize_names: true)
          expect(data[:available]).to be_truthy
          expect(data[:latest_version]).to eq('7.0.0')
          expect(data[:exec_name]).to eq('hashcat.exe')
          expect(data[:message]).to eq('A newer version of the cracker is available')
        end
      end

      response(200, 'operating system not found') do
        let(:operating_system) { 'linux' }
        let(:version) { '1.0.0' }

        schema '$ref' => '#/components/schemas/cracker_update'

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test! do |response| # rubocop:disable RSpec/MultipleExpectations
          data = JSON.parse(response.body, symbolize_names: true)
          expect(data[:message]).to eq('No updated crackers found for the specified operating system')
          expect(data[:available]).to be_falsey
        end
      end

      response(400, 'operating system parameter invalid') do
        let(:operating_system) { nil }
        let(:version) { '1.0.0' }

        schema '$ref' => '#/components/schemas/error_object'

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body, symbolize_names: true)
          expect(data[:error]).to eq('Operating System is required')
        end
      end
    end
  end

  path '/api/v1/client/crackers' do
    get('list crackers') do
      tags "Crackers"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'listCrackers'

      let(:agent) { create(:agent) }
      let(:cracker) { create(:cracker) }
      let(:cracker_binary) { create(:cracker_binary, cracker: cracker) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(200, 'successful') do
        schema type: :array,
               items: {
                 '$ref' => '#/components/schemas/cracker'
               }
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/client/crackers/{id}' do
    get('show cracker') do
      parameter name: 'id', in: :path, type: :string, description: 'id'
      tags "Crackers"
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      operationId 'showCracker'

      let(:agent) { create(:agent) }
      let(:cracker) { create(:cracker) }
      let(:cracker_binary) { create(:cracker_binary, cracker: cracker) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      response(200, 'successful') do
        let(:id) { cracker.id }

        schema '$ref' => '#/components/schemas/cracker'

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        run_test!
      end
    end
  end
end
