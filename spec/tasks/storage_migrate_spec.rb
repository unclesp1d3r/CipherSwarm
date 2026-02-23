# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "rake"

RSpec.describe "storage:migrate_to_local", type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks unless Rake::Task.task_defined?("storage:migrate_to_local")
  end

  let(:task) { Rake::Task["storage:migrate_to_local"] }
  let(:output) { StringIO.new }
  let(:original_stdout) { $stdout }

  # rubocop:disable RSpec/ExpectOutput -- rake task writes to $stdout directly; capture is required
  before do
    task.reenable
    original_stdout
    $stdout = output
  end

  after do
    $stdout = original_stdout
    ENV.delete("DRY_RUN")
    ENV.delete("SOURCE_SERVICE")
  end
  # rubocop:enable RSpec/ExpectOutput

  describe "when no non-local blobs exist" do
    it "reports zero blobs and completes successfully" do
      expect { task.invoke }.not_to raise_error
      expect(output.string).to include("No blobs to migrate")
    end
  end

  describe "when local service is not configured" do
    it "aborts with a clear error message" do
      services = ActiveStorage::Blob.services
      allow(services).to receive(:fetch).with(:local).and_raise(KeyError)

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(output.string).to include("No 'local' service configured")
    end
  end

  describe "dry run mode" do
    let(:hash_list) { create(:hash_list) }

    before do
      hash_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations
    end

    it "previews migration without making changes" do
      stub_source_service("s3")
      ENV["DRY_RUN"] = "true"

      expect { task.invoke }.not_to raise_error

      expect(output.string).to include("[DRY RUN]")
      expect(output.string).to include("Would migrate")
      expect(hash_list.file.blob.reload.service_name).to eq("s3")
    end

    it "uses 'Would migrate' label in summary" do
      stub_source_service("s3")
      ENV["DRY_RUN"] = "true"

      expect { task.invoke }.not_to raise_error
      expect(output.string).to include("Would migrate: 1")
    end
  end

  describe "live migration" do
    let(:hash_list) { create(:hash_list) }
    let(:disk_service) { ActiveStorage::Blob.services.fetch(:local) }

    before do
      hash_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations
    end

    it "migrates a blob from S3 to local in a single pass" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")

      allow(source_service).to receive(:download).with(blob.key).and_yield("test content")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(false)
      allow(disk_service).to receive(:upload)
      stub_checksum_match(blob)

      expect { task.invoke }.not_to raise_error

      expect(output.string).to include("[OK]")
      expect(blob.reload.service_name).to eq("local")
    end

    it "skips blobs already on disk and updates service_name" do
      blob = hash_list.file.blob
      stub_source_service("s3")

      allow(disk_service).to receive(:exist?).with(blob.key).and_return(true)

      expect { task.invoke }.not_to raise_error

      expect(output.string).to include("[SKIP]")
      expect(output.string).to include("already exists on disk")
      expect(blob.reload.service_name).to eq("local")
    end

    it "reports checksum mismatch as an error" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")

      allow(source_service).to receive(:download).with(blob.key).and_yield("corrupted")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(false)
      stub_checksum_mismatch

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }

      expect(output.string).to include("[ERROR]")
      expect(output.string).to include("checksum mismatch")
      expect(blob.reload.service_name).to eq("s3")
    end

    it "continues processing after a single blob failure" do
      second_hash_list = create(:hash_list, name: "second-list")
      second_hash_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations
      source_service = stub_source_service("s3")

      first_blob = hash_list.file.blob
      allow(source_service).to receive(:download).with(first_blob.key).and_raise(StandardError, "network timeout")
      allow(disk_service).to receive(:exist?).with(first_blob.key).and_return(false)

      second_blob = second_hash_list.file.blob
      allow(source_service).to receive(:download).with(second_blob.key).and_yield("content")
      allow(disk_service).to receive(:exist?).with(second_blob.key).and_return(false)
      allow(disk_service).to receive(:upload)
      stub_checksum_match(second_blob)

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }

      expect(output.string).to include("Migrated: 1")
      expect(output.string).to include("Failed:   1")
    end

    it "reports upload failures with specific error details" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")

      allow(source_service).to receive(:download).with(blob.key).and_yield("content")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(false)
      allow(disk_service).to receive(:upload).and_raise(StandardError, "write error")
      stub_checksum_match(blob)

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(output.string).to include("[ERROR]")
      expect(output.string).to include("write error")
    end

    it "aborts immediately on disk full" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")

      allow(source_service).to receive(:download).with(blob.key).and_yield("content")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(false)
      allow(disk_service).to receive(:upload).and_raise(Errno::ENOSPC, "No space left")
      stub_checksum_match(blob)

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(output.string).to include("[FATAL]")
      expect(output.string).to include("disk full")
    end

    it "aborts immediately on permission denied" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")

      allow(source_service).to receive(:download).with(blob.key).and_yield("content")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(false)
      allow(disk_service).to receive(:upload).and_raise(Errno::EACCES, "Permission denied")
      stub_checksum_match(blob)

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(output.string).to include("[FATAL]")
      expect(output.string).to include("permission denied")
    end
  end

  describe "SOURCE_SERVICE override" do
    let(:hash_list) { create(:hash_list) }

    before do
      hash_list.file.blob.update_column(:service_name, "minio") # rubocop:disable Rails/SkipsModelValidations
    end

    it "uses the overridden service for download" do
      blob = hash_list.file.blob
      disk_service = ActiveStorage::Blob.services.fetch(:local)
      s3_service = stub_source_service("s3")

      allow(s3_service).to receive(:download).with(blob.key).and_yield("content")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(false)
      allow(disk_service).to receive(:upload)
      stub_checksum_match(blob)

      ENV["SOURCE_SERVICE"] = "s3"
      expect { task.invoke }.not_to raise_error

      expect(output.string).to include("[OK]")
      expect(blob.reload.service_name).to eq("local")
    end
  end

  describe "missing source service" do
    let(:hash_list) { create(:hash_list) }

    before do
      hash_list.file.blob.update_column(:service_name, "minio") # rubocop:disable Rails/SkipsModelValidations
    end

    it "aborts with an error when the service is not configured" do
      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }

      expect(output.string).to include("ERROR")
      expect(output.string).to include("minio")
    end
  end

  describe "summary output" do
    it "prints migration summary header" do
      expect { task.invoke }.not_to raise_error
      expect(output.string).to include("Storage Migration")
    end

    it "shows INTERRUPTED status in summary" do
      StorageMigration.print_summary({ migrated: 5, skipped: 0, failed: 0, interrupted: true, dry_run: false })
      expect(output.string).to include("INTERRUPTED (safe to re-run)")
    end

    it "shows COMPLETE status when not interrupted" do
      StorageMigration.print_summary({ migrated: 5, skipped: 0, failed: 0, interrupted: false, dry_run: false })
      expect(output.string).to include("COMPLETE")
    end
  end

  describe "print_progress" do
    it "does not print when total is zero" do
      StorageMigration.print_progress(0, 0)
      expect(output.string).to be_empty
    end
  end

  describe "configured_service_names" do
    it "returns empty array when registry internals are not accessible" do
      registry = ActiveStorage::Blob.services
      allow(registry).to receive(:instance_variable_get).with(:@configurations).and_return(nil)
      allow(Rails.logger).to receive(:warn)

      result = StorageMigration.configured_service_names

      expect(result).to eq([])
      expect(output.string).to include("WARNING")
    end
  end

  describe "resolve_source_service" do
    let(:hash_list) { create(:hash_list) }

    it "returns nil when the service is not in the registry" do
      blob = hash_list.file.blob
      blob.update_column(:service_name, "nonexistent") # rubocop:disable Rails/SkipsModelValidations

      result = StorageMigration.resolve_source_service(blob)
      expect(result).to be_nil
    end
  end

  describe "interrupt handling" do
    let(:hash_list) { create(:hash_list) }
    let!(:second_list) { create(:hash_list, name: "interrupt-test") }

    before do
      # Two blobs needed so the second iteration hits `break if interrupted`
      hash_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations
      second_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations
    end

    it "stops processing and reports interrupted status on INT signal" do
      source_service = stub_source_service("s3")
      disk_service = ActiveStorage::Blob.services.fetch(:local)

      # Capture the trap handler instead of sending a real SIGINT (which can segfault Ruby).
      int_handler = nil
      allow(StorageMigration).to receive(:trap).with("INT") { |&blk| int_handler = blk }

      first_download = true
      allow(source_service).to receive(:download) do |_key, &block|
        (int_handler&.call; first_download = false) if first_download
        block&.call("content")
      end
      allow(disk_service).to receive(:exist?).and_return(false)
      allow(disk_service).to receive(:upload)
      stub_checksum_match(hash_list.file.blob)

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(output.string).to include("INTERRUPTED (safe to re-run)")
    end
  end

  describe "per-blob source service skip" do
    let(:hash_list) { create(:hash_list) }

    before do
      hash_list.file.blob.update_column(:service_name, "minio") # rubocop:disable Rails/SkipsModelValidations
    end

    it "skips blobs when source service is unavailable at runtime" do
      ENV["SOURCE_SERVICE"] = "s3"
      allow(StorageMigration).to receive(:resolve_source_service).and_return(nil)

      expect { task.invoke }.not_to raise_error

      expect(output.string).to include("[SKIP]")
      expect(output.string).to include("source service not configured")
      expect(output.string).to include("Skipped:  1")
    end
  end

  describe "logging" do
    let(:hash_list) { create(:hash_list) }

    before do
      hash_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations
    end

    it "logs completion summary to Rails.logger" do
      stub_source_service("s3")
      ENV["DRY_RUN"] = "true"

      allow(Rails.logger).to receive(:info)

      expect { task.invoke }.not_to raise_error
      expect(Rails.logger).to have_received(:info).with(/\[StorageMigration\] Complete/)
    end
  end

  private

  def stub_source_service(name)
    service = instance_double(ActiveStorage::Service, download: nil)
    services = ActiveStorage::Blob.services
    allow(services).to receive(:fetch).and_call_original
    allow(services).to receive(:fetch).with(name.to_sym).and_return(service)
    service
  end

  def stub_checksum_match(blob)
    allow_any_instance_of(Digest::MD5).to receive(:base64digest).and_return(blob.checksum) # rubocop:disable RSpec/AnyInstance
  end

  def stub_checksum_mismatch
    allow_any_instance_of(Digest::MD5).to receive(:base64digest).and_return("bad_checksum") # rubocop:disable RSpec/AnyInstance
  end
end
