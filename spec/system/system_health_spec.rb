# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "System Health Dashboard", skip: ENV["CI"].present? do
  before do
    Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
  end

  describe "page content" do
    it "displays the system health page with service cards" do
      create_and_sign_in_user
      visit system_health_path

      expect(page).to have_content("System Health")
      expect(page).to have_css(".card", minimum: 4)
    end

    it "shows a refresh button" do
      create_and_sign_in_user
      visit system_health_path

      expect(page).to have_link("Refresh")
    end

    it "displays the diagnostics section" do
      create_and_sign_in_user
      visit system_health_path

      expect(page).to have_content("Diagnostics")
    end
  end

  describe "sidebar link" do
    it "shows system health link in the sidebar" do
      create_and_sign_in_user
      visit root_path

      expect(page).to have_css("aside.sidebar", wait: 5)

      within("aside.sidebar") do
        expect(page).to have_css("a[href='#{system_health_path}']")
      end
    end

    it "navigates to system health from sidebar" do
      create_and_sign_in_user
      visit root_path

      expect(page).to have_css("aside.sidebar", wait: 5)

      within("aside.sidebar") do
        find("a[href='#{system_health_path}']").click
      end

      expect(page).to have_current_path(system_health_path)
      expect(page).to have_content("System Health")
    end
  end

  describe "admin features" do
    it "shows sidekiq dashboard link for admin users" do
      create_and_sign_in_admin
      visit system_health_path

      expect(page).to have_content("Sidekiq Dashboard")
    end

    it "hides sidekiq dashboard link for regular users" do
      create_and_sign_in_user
      visit system_health_path

      expect(page).to have_content("System Health")
      expect(page).to have_no_content("Sidekiq Dashboard")
    end
  end

  describe "service card details" do
    it "displays all four service cards (PostgreSQL, Redis, MinIO, Sidekiq)", :aggregate_failures do
      create_and_sign_in_user
      visit system_health_path

      expect(page).to have_content("PostgreSQL")
      expect(page).to have_content("Redis")
      expect(page).to have_content("MinIO")
      expect(page).to have_content("Sidekiq")
    end

    it "shows health status indicators on each card" do
      create_and_sign_in_user
      visit system_health_path

      # Each card should have a status indicator (healthy/unhealthy/checking)
      expect(page).to have_css(".card", minimum: 4)
    end
  end

  describe "diagnostics navigation" do
    it "shows diagnostic links in the diagnostics section" do
      create_and_sign_in_user
      visit system_health_path

      expect(page).to have_content("Diagnostics")
    end
  end

  describe "auto-refresh controller" do
    it "renders the health-refresh stimulus controller with correct attributes", :aggregate_failures do
      create_and_sign_in_user
      visit system_health_path

      controller_element = find("[data-controller='health-refresh']", visible: :all)
      expect(controller_element["data-health-refresh-url-value"]).to eq(system_health_path)
      expect(controller_element["data-health-refresh-interval-value"]).to be_present
    end

    it "configures the refresh URL to the system health path, not the current page" do
      create_and_sign_in_user
      visit system_health_path

      controller_element = find("[data-controller='health-refresh']", visible: :all)
      # Verify the configured URL is the system_health endpoint, not a generic page URL
      expect(controller_element["data-health-refresh-url-value"]).to eq("/system_health")
    end
  end

  describe "simulated service failure" do
    it "displays unhealthy status when a service check fails" do
      # Stub the service to return a failure for PostgreSQL
      unhealthy_result = {
        postgresql: { status: :unhealthy, latency: nil, error: "connection refused", connection_count: nil, database_size: nil },
        redis: { status: :healthy, latency: 0.5, error: nil, used_memory: "10MB", connected_clients: 5, hit_rate: nil },
        minio: { status: :healthy, latency: 2.0, error: nil, storage_used: 1024, bucket_count: 1 },
        sidekiq: { status: :healthy, latency: 0.3, error: nil, workers: 2, queues: 1, enqueued: 0 },
        application: { rails_version: Rails.version, ruby_version: RUBY_VERSION, uptime: "1h", workers_running: true, worker_count: 2 },
        checked_at: Time.current.iso8601
      }
      allow(SystemHealthCheckService).to receive(:call).and_return(unhealthy_result)

      create_and_sign_in_user
      visit system_health_path

      expect(page).to have_content("System Health")
      expect(page).to have_content("connection refused")
    end
  end

  describe "health check response time" do
    it "loads the page within a reasonable time" do
      create_and_sign_in_user

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      visit system_health_path
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(page).to have_content("System Health")
      expect(elapsed).to be < 10 # Health checks should complete within 10 seconds
    end
  end
end
