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
    original_stdout # force evaluation before reassignment
    $stdout = output
  end

  after do
    $stdout = original_stdout
    ENV.delete("DRY_RUN")
    ENV.delete("SOURCE_SERVICE")
  end
  # rubocop:enable RSpec/ExpectOutput

  describe "when no non-local blobs exist" do
    it "reports zero blobs and exits cleanly" do
      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      expect(output.string).to include("No blobs to migrate")
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
  end

  describe "live migration" do
    let(:hash_list) { create(:hash_list) }
    let(:disk_service) { ActiveStorage::Blob.services.fetch(:local) }

    before do
      hash_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations
    end

    it "migrates a blob from S3 to local" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")

      allow(source_service).to receive(:download).with(blob.key).and_yield("test file content")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(false)
      allow(disk_service).to receive(:upload)
      stub_checksum_match(blob)

      expect { task.invoke }.not_to raise_error

      expect(output.string).to include("[OK]")
      expect(blob.reload.service_name).to eq("local")
    end

    it "skips blobs already on disk and updates service_name" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")
      stub_checksum_match(blob)

      allow(source_service).to receive(:download).with(blob.key).and_yield("content")
      allow(disk_service).to receive(:exist?).with(blob.key).and_return(true)

      expect { task.invoke }.not_to raise_error

      expect(output.string).to include("[SKIP]")
      expect(output.string).to include("already exists on disk")
      expect(blob.reload.service_name).to eq("local")
    end

    it "reports checksum mismatch as an error" do
      blob = hash_list.file.blob
      source_service = stub_source_service("s3")

      allow(source_service).to receive(:download).with(blob.key).and_yield("corrupted data")
      allow_any_instance_of(Digest::MD5).to receive(:base64digest).and_return("bad_checksum") # rubocop:disable RSpec/AnyInstance

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }

      expect(output.string).to include("[ERROR]")
      expect(output.string).to include("checksum mismatch")
      expect(blob.reload.service_name).to eq("s3")
    end

    it "continues processing after a single blob failure" do
      second_hash_list = create(:hash_list, name: "second-list")
      second_hash_list.file.blob.update_column(:service_name, "s3") # rubocop:disable Rails/SkipsModelValidations

      source_service = stub_source_service("s3")

      # First blob: download raises error
      first_blob = hash_list.file.blob
      allow(source_service).to receive(:download).with(first_blob.key).and_raise(StandardError, "network timeout")

      # Second blob: succeeds
      second_blob = second_hash_list.file.blob
      allow(source_service).to receive(:download).with(second_blob.key).and_yield("content")
      allow(disk_service).to receive(:exist?).with(second_blob.key).and_return(false)
      allow(disk_service).to receive(:upload)
      stub_checksum_match(second_blob)

      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }

      expect(output.string).to include("Migrated: 1")
      expect(output.string).to include("Failed:   1")
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

    it "exits with an error when the service is not configured" do
      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }

      expect(output.string).to include("ERROR")
      expect(output.string).to include("minio")
    end
  end

  describe "summary output" do
    it "prints migration summary header" do
      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      expect(output.string).to include("Storage Migration")
    end
  end

  private

  def stub_source_service(name)
    service = double("#{name}_service") # rubocop:disable RSpec/VerifiedDoubles
    services = ActiveStorage::Blob.services
    allow(services).to receive(:fetch).and_call_original
    allow(services).to receive(:fetch).with(name.to_sym).and_return(service)
    service
  end

  def stub_checksum_match(blob)
    allow_any_instance_of(Digest::MD5).to receive(:base64digest).and_return(blob.checksum) # rubocop:disable RSpec/AnyInstance
  end
end
