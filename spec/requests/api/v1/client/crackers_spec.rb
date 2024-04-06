# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/client/crackers' do
  path '/api/v1/client/crackers/check_for_cracker_update' do
    get('check_for_cracker_update cracker') do
      tags "Crackers"
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      operationId 'checkForCrackerUpdate'

      parameter name: :operating_system, in: :query, type: :string, description: 'operating_system'
      parameter name: :version, in: :query, type: :string, description: 'version'

      let!(:agent) { create(:agent) }
      let(:Authorization) { "Bearer #{agent.token}" } # rubocop:disable RSpec/VariableName

      before do
        create(:cracker_binary, version: "7.0.0",
                                operating_systems: [create(:operating_system,
                                                            name: "windows",
                                                            cracker_command: "hashcat.exe")])
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

        run_test! do |response|
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

        run_test! do |response|
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
end
