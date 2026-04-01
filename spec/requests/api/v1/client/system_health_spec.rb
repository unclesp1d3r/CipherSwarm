# frozen_string_literal: true

# SPDX-FileCopyrightText:  2026 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "api/v1/client/system_health" do
  let(:agent) { create(:agent) }
  let(:health_response) do
    {
      postgresql: { status: :healthy, latency: 1.23, error: nil, connection_count: 5, database_size: 1024, pool: {} },
      redis: { status: :healthy, latency: 0.45, error: nil, used_memory: "1M", connected_clients: 2, hit_rate: 99.0 },
      storage: { status: :healthy, latency: 2.10, error: nil, storage_used: 500, bucket_count: nil },
      sidekiq: { status: :healthy, latency: 0.80, error: nil, workers: 1, queues: 1, enqueued: 0 },
      application: { rails_version: "8.0.0", ruby_version: "3.4.0", uptime: "1h 5m", workers_running: true, worker_count: 1 },
      checked_at: "2026-04-01T00:00:00Z"
    }
  end

  before do
    allow(SystemHealthCheckService).to receive(:call).and_return(health_response)
  end

  describe "GET /api/v1/client/system_health" do
    context "with valid agent token" do
      it "returns 200 with expected health check keys" do
        get "/api/v1/client/system_health",
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.keys).to match_array(%i[postgresql redis storage sidekiq application checked_at])
      end
    end

    context "without auth token" do
      it "returns 401 unauthorized" do
        get "/api/v1/client/system_health"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
