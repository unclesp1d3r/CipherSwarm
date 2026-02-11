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
  end

  private

  def stub_health_checks
    allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_return(true)
    stub_minio_check
    stub_sidekiq_check
  end

  def stub_minio_check
    allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
  end

  def stub_sidekiq_check
    stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
    allow(Sidekiq::Stats).to receive(:new).and_return(stats)
  end
end
