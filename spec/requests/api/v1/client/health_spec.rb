# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "swagger_helper"

RSpec.describe "api/v1/client/health" do
  path "/api/v1/client/health" do
    get "Health check (unauthenticated)" do
      tags "Client"
      description "Returns server health status. Does not require authentication. " \
                  "Agents use this endpoint to verify server reachability before " \
                  "attempting authenticated requests."
      security []
      produces "application/json"
      operationId "getHealth"

      response(200, "healthy") do
        schema type: :object,
               properties: {
                 status: { type: :string, description: "Overall health status (ok or degraded)" },
                 api_version: { type: :integer, description: "API version" },
                 timestamp: { type: :string, format: "date-time", description: "Server timestamp" },
                 database: { type: :string, description: "Database health (healthy or unhealthy)" }
               },
               required: %i[status api_version timestamp database]

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
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body, symbolize_names: true)
          expect(data[:status]).to eq("ok")
          expect(data[:api_version]).to eq(1)
          expect(data[:database]).to eq("healthy")
          expect(data[:timestamp]).to be_present
        end
      end

      response(503, "degraded") do
        schema type: :object,
               properties: {
                 status: { type: :string, description: "Overall health status (ok or degraded)" },
                 api_version: { type: :integer, description: "API version" },
                 timestamp: { type: :string, format: "date-time", description: "Server timestamp" },
                 database: { type: :string, description: "Database health (healthy or unhealthy)" }
               },
               required: %i[status api_version timestamp database]

        before do
          allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
          allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_raise(StandardError.new("connection refused"))
          allow(Rails.logger).to receive(:error)
        end

        run_test! do
          data = JSON.parse(response.body, symbolize_names: true)
          expect(data[:status]).to eq("degraded")
          expect(data[:database]).to eq("unhealthy")
        end
      end
    end
  end
end
