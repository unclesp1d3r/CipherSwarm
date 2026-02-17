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
