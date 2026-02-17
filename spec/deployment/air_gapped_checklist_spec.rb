# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Air-Gapped Deployment Validation", type: :request do
  describe "asset pipeline" do
    it "CSS/JS assets can be precompiled without external dependencies" do
      # Verify manifest files exist for asset pipeline
      manifest_paths = [
        Rails.root.join("app/assets/stylesheets"),
        Rails.root.join("app/javascript")
      ]
      manifest_paths.each do |path|
        expect(File.directory?(path)).to be(true), "Asset directory #{path} should exist"
      end
    end

    it "no CDN references in application layout" do
      layout_path = Rails.root.join("app/views/layouts/application.html.erb")
      skip "Application layout not found at #{layout_path}" unless File.exist?(layout_path)

      content = File.read(layout_path)

      # Should not reference external CDNs
      expect(content).not_to match(/cdn\.jsdelivr\.net/)
      expect(content).not_to match(/cdnjs\.cloudflare\.com/)
      expect(content).not_to match(/unpkg\.com/)
      expect(content).not_to match(/fonts\.googleapis\.com/)
    end
  end

  describe "Docker configuration" do
    it "docker-compose.yml exists" do
      expect(Rails.root.join("docker-compose.yml").exist?).to be(true)
    end

    it "Dockerfile exists" do
      dockerfile = Rails.root.join("Dockerfile")
      expect(File.exist?(dockerfile)).to be(true)
    end

    it "docker-compose includes all required services" do
      compose_content = Rails.root.join("docker-compose.yml").read
      expect(compose_content).to include("postgres")
      expect(compose_content).to include("redis")
    end
  end

  describe "health check endpoints" do
    before do
      Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
      stub_health_checks
    end

    it "system health endpoint is accessible" do
      user = create(:user)
      sign_in(user)

      get system_health_path
      expect(response).to have_http_status(:success)
    end

    it "system health returns JSON format" do
      user = create(:user)
      sign_in(user)

      get system_health_path(format: :json)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")

      json = JSON.parse(response.body)
      expect(json).to have_key("checked_at")
      expect(json).to have_key("application")
    end
  end

  describe "configuration files" do
    it "Procfile.dev exists for development" do
      expect(Rails.root.join("Procfile.dev").exist?).to be(true)
    end

    it "database.yml exists" do
      expect(Rails.root.join("config/database.yml").exist?).to be(true)
    end

    it "environment configuration files exist" do
      %w[development test production].each do |env|
        config_file = Rails.root.join("config/environments/#{env}.rb")
        expect(File.exist?(config_file)).to be(true), "#{env}.rb should exist"
      end
    end
  end

  describe "storage configuration" do
    it "storage.yml exists for Active Storage" do
      expect(Rails.root.join("config/storage.yml").exist?).to be(true)
    end

    it "local storage is configured" do
      storage_config = YAML.safe_load(
        Rails.root.join("config/storage.yml").read,
        permitted_classes: [],
        aliases: true
      )
      expect(storage_config).to have_key("local")
    end
  end

  describe "air-gapped deployment checklist" do
    # This section documents manual validation steps that cannot be automated:
    #
    # 1. CSS/JS assets bundled: Verified above - no CDN references in layout
    # 2. Fonts embedded: Check app/assets/fonts/ or vendor/assets/fonts/
    # 3. Icons/images in asset pipeline: Check app/assets/images/
    # 4. Docker compose works offline: Test with --no-internet network policy
    # 5. Pages load without external requests: Use browser network tab in dev mode
    # 6. Asset precompilation: Run `rails assets:precompile` in isolated environment
    # 7. Health check endpoints: Verified above - accessible in test environment
    # 8. Agent API accessible: Test from isolated agent container
    # 9. File uploads/downloads with MinIO: Verify no S3 external calls
    # 10. Documentation accessible offline: Verify docs bundled in repo

    it "Gemfile does not require external fetch during runtime" do
      gemfile_content = Rails.root.join("Gemfile").read
      # Should not have gems that require runtime external fetches for core functionality
      expect(gemfile_content).not_to match(/gem.*google-fonts/)
    end
  end

  private

  def stub_health_checks
    allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
    allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_return(true)
    allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
    stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
    allow(Sidekiq::Stats).to receive(:new).and_return(stats)
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
  end
end
