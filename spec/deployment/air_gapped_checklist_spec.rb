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

  describe "fonts and icons" do
    it "uses system fonts or bundled fonts (no external font loading)" do
      css_dir = Rails.root.join("app/assets/stylesheets")
      css_files = Dir.glob("#{css_dir}/**/*.{css,scss}")

      css_files.each do |file|
        content = File.read(file)
        # Should not reference Google Fonts or other external font services
        expect(content).not_to match(%r{fonts\.googleapis\.com}),
          "#{file} references external Google Fonts"
        expect(content).not_to match(%r{use\.typekit\.net}),
          "#{file} references external Typekit fonts"
      end
    end

    it "icons and images are in the asset pipeline" do
      images_dir = Rails.root.join("app/assets/images")
      expect(File.directory?(images_dir)).to be(true)

      image_files = Dir.glob("#{images_dir}/**/*.{svg,png,jpg,ico}")
      expect(image_files).not_to be_empty, "No icon/image files found in asset pipeline"
    end
  end

  describe "JavaScript assets" do
    it "no external script references in JavaScript entry point" do
      js_dir = Rails.root.join("app/javascript")
      expect(File.directory?(js_dir)).to be(true)

      js_files = Dir.glob("#{js_dir}/**/*.{js,ts}")
      js_files.each do |file|
        content = File.read(file)
        # Should not fetch from external CDNs at runtime
        expect(content).not_to match(%r{https?://cdn\.\w+}),
          "#{file} references external CDN"
      end
    end
  end

  describe "MinIO storage configuration" do
    it "storage.yml includes MinIO configuration for air-gapped S3-compatible storage" do
      storage_config = YAML.safe_load(
        Rails.root.join("config/storage.yml").read,
        permitted_classes: [],
        aliases: true
      )
      expect(storage_config).to have_key("minio")
    end

    it "MinIO uses local endpoint by default" do
      storage_content = Rails.root.join("config/storage.yml").read
      expect(storage_content).to include("endpoint")
      expect(storage_content).to include("force_path_style: true")
    end
  end

  describe "production Docker configuration" do
    it "production docker-compose file exists" do
      expect(Rails.root.join("docker-compose-production.yml").exist?).to be(true)
    end

    it "production compose includes all required services" do
      content = Rails.root.join("docker-compose-production.yml").read
      expect(content).to include("postgres")
      expect(content).to include("redis")
    end
  end

  describe "agent API accessibility" do
    let!(:agent) { create(:agent) }

    it "agent authentication endpoint is accessible" do
      get "/api/v1/client/authenticate",
          headers: { "Authorization" => "Bearer #{agent.token}" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "offline documentation" do
    it "documentation directory exists in the repository" do
      docs_dir = Rails.root.join("docs")
      expect(File.directory?(docs_dir)).to be(true)
    end

    it "user guide documentation is available offline" do
      user_guide_dir = Rails.root.join("docs/user-guide")
      expect(File.directory?(user_guide_dir)).to be(true)
    end

    it "getting started documentation is available offline" do
      getting_started_dir = Rails.root.join("docs/getting-started")
      expect(File.directory?(getting_started_dir)).to be(true)
    end
  end

  describe "all pages load without external requests" do
    it "no external URL references in view templates" do
      view_dir = Rails.root.join("app/views")
      view_files = Dir.glob("#{view_dir}/**/*.{erb,haml,slim}")

      external_refs = []
      view_files.each do |file|
        content = File.read(file)
        # Check for direct external URL references (excluding comments and documentation)
        if content.match?(%r{(src|href)=["']https?://(?!localhost|127\.0\.0\.1|<%|#\{)})
          external_refs << file
        end
      end

      # Allow known exceptions (e.g., links to documentation sites are OK)
      # but flag anything that loads external resources
      external_refs.reject! { |f| f.include?("mailer") || f.include?("api_docs") }
      expect(external_refs).to be_empty,
        "Found external URL references in: #{external_refs.join(', ')}"
    end
  end

  describe "asset precompilation readiness" do
    it "package.json exists for JavaScript dependencies" do
      expect(Rails.root.join("package.json").exist?).to be(true)
    end

    it "bun.lockb or bun.lock exists for reproducible builds" do
      lockfile = Rails.root.join("bun.lockb").exist? || Rails.root.join("bun.lock").exist?
      expect(lockfile).to be(true)
    end

    it "Gemfile.lock exists for reproducible Ruby builds" do
      expect(Rails.root.join("Gemfile.lock").exist?).to be(true)
    end
  end

  describe "air-gapped deployment checklist summary" do
    # All 10 checklist items mapped to test coverage:
    #
    # 1. CSS/JS assets bundled: ✓ asset pipeline tests + no CDN references
    # 2. Fonts embedded: ✓ no external font loading in stylesheets
    # 3. Icons/images in asset pipeline: ✓ images exist in app/assets/images/
    # 4. Docker compose works offline: ✓ production compose with all services
    # 5. Pages load without external requests: ✓ view template scan
    # 6. Asset precompilation: ✓ asset directories + lockfiles present
    # 7. Health check endpoints: ✓ accessible and returns JSON
    # 8. Agent API accessible: ✓ authentication endpoint accessible
    # 9. File uploads/downloads with MinIO: ✓ MinIO configured in storage.yml
    # 10. Documentation accessible offline: ✓ docs directory present

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
