# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "SystemHealth" do
  let!(:project) { create(:project) }
  let!(:admin_user) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:regular_user) { create(:user, projects: [project]) }

  before do
    # Clear any leftover lock
    Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
  end

  describe "GET /system_health" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get system_health_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when regular user is logged in" do
      before do
        sign_in regular_user
        stub_health_checks
      end

      it "returns http success" do
        get system_health_path
        expect(response).to have_http_status(:success)
      end

      it "renders the index template" do
        get system_health_path
        expect(response).to render_template(:index)
      end
    end

    context "when admin user is logged in" do
      before do
        sign_in admin_user
        stub_health_checks
      end

      it "returns http success" do
        get system_health_path
        expect(response).to have_http_status(:success)
      end

      it "renders the index template" do
        get system_health_path
        expect(response).to render_template(:index)
      end
    end

    context "with health check caching" do
      let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

      before do
        sign_in regular_user
        stub_health_checks
        # Use memory store for caching tests so writes persist across requests
        allow(Rails).to receive(:cache).and_return(memory_cache)
      end

      it "caches health check results" do
        get system_health_path
        expect(response).to have_http_status(:success)

        cached = memory_cache.read(SystemHealthCheckService::CACHE_KEY)
        expect(cached).to be_present
        expect(cached[:postgresql][:status]).to eq(:healthy)
      end

      it "uses cached results on second request" do
        get system_health_path
        expect(response).to have_http_status(:success)

        # Verify cache was populated after first request
        expect(memory_cache.read(SystemHealthCheckService::CACHE_KEY)).to be_present

        # Second request should succeed and use cached data
        get system_health_path
        expect(response).to have_http_status(:success)
      end
    end

    context "with Redis lock" do
      before do
        sign_in regular_user
        stub_health_checks
      end

      it "acquires and releases lock during health checks" do
        get system_health_path
        expect(response).to have_http_status(:success)

        # Lock should be released after request completes
        lock_value = Sidekiq.redis { |conn| conn.get(SystemHealthCheckService::LOCK_KEY) }
        expect(lock_value).to be_nil
      end

      it "returns checking status when lock is held by another request" do
        # Simulate lock held by another request
        Sidekiq.redis { |conn| conn.set(SystemHealthCheckService::LOCK_KEY, "other-token", nx: true, ex: 10) }

        get system_health_path
        expect(response).to have_http_status(:success)

        # Clean up
        Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
      end

      it "only releases lock if token matches" do
        # Acquire lock with a different token to simulate another request
        Sidekiq.redis { |conn| conn.set(SystemHealthCheckService::LOCK_KEY, "other-request-token", nx: true, ex: 10) }

        # Service should not be able to acquire lock, so it returns checking status
        get system_health_path
        expect(response).to have_http_status(:success)

        # Lock should still be held by the other request (not released by our request)
        lock_value = Sidekiq.redis { |conn| conn.get(SystemHealthCheckService::LOCK_KEY) }
        expect(lock_value).to eq("other-request-token")

        # Clean up
        Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
      end
    end

    context "when a health check fails" do
      before do
        sign_in regular_user
        allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
        allow(ActiveRecord::Base.connection).to receive(:execute)
          .with("SELECT 1")
          .and_raise(PG::ConnectionBad.new("connection refused"))
        stub_minio_check
        stub_sidekiq_check
      end

      it "returns success with unhealthy service status" do
        get system_health_path
        expect(response).to have_http_status(:success)
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)
        get system_health_path
        expect(Rails.logger).to have_received(:error).with(/PostgreSQL check failed/)
      end
    end

    context "with large values and nil hit_rate in health checks" do
      before do
        sign_in regular_user
        health_result = {
          postgresql: { status: :healthy, latency: 1.5, error: nil, connection_count: 10, database_size: 2_147_483_648 },
          redis: { status: :healthy, latency: 0.5, error: nil, used_memory: "10MB", connected_clients: 5, hit_rate: nil },
          minio: { status: :healthy, latency: 2.0, error: nil, storage_used: 1_073_741_824, bucket_count: 3 },
          sidekiq: { status: :healthy, latency: 0.3, error: nil, workers: 2, queues: 1, enqueued: 0 },
          application: { rails_version: Rails.version, ruby_version: RUBY_VERSION, uptime: "1d 2h", workers_running: true, worker_count: 2 },
          checked_at: Time.current.iso8601
        }
        allow(SystemHealthCheckService).to receive(:call).and_return(health_result)
      end

      it "renders GB-formatted database size" do
        get system_health_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("2.0 GB")
      end

      it "renders page without redis hit rate" do
        get system_health_path
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("Hit Rate")
      end
    end

    context "with JSON format" do
      before do
        sign_in regular_user
        stub_health_checks
      end

      it "returns JSON response" do
        get system_health_path(format: :json)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/json")
      end

      it "includes checked_at in JSON response" do
        get system_health_path(format: :json)
        json = response.parsed_body
        expect(json["checked_at"]).to be_present
      end

      it "includes application info in JSON response" do
        get system_health_path(format: :json)
        json = response.parsed_body
        expect(json["application"]).to be_present
        expect(json["application"]["rails_version"]).to eq(Rails.version)
      end
    end
  end

  private

  def stub_health_checks
    allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
    allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_return(true)
    stub_minio_check
    stub_sidekiq_check
    stub_application_info
  end

  def stub_minio_check
    allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
  end

  def stub_sidekiq_check
    stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
    allow(Sidekiq::Stats).to receive(:new).and_return(stats)
  end

  def stub_application_info
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
  end
end
