# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

namespace :storage do
  desc "Migrate files from S3/MinIO to local disk storage"
  task migrate_to_local: :environment do
    migrated = 0
    skipped = 0
    failed = 0
    interrupted = false

    disk_service = resolve_disk_service
    non_local_blobs = ActiveStorage::Blob.where.not(service_name: "local")

    total = non_local_blobs.count
    dry_run = ENV["DRY_RUN"].present?

    $stdout.puts "Storage Migration: S3/MinIO → Local Disk"
    $stdout.puts "=" * 50
    $stdout.puts "Mode: #{dry_run ? 'DRY RUN (no changes will be made)' : 'LIVE'}"
    $stdout.puts "Total blobs to process: #{total}"
    $stdout.puts "=" * 50

    if total.zero?
      $stdout.puts "No blobs to migrate. All files are already on local storage."
      exit 0
    end

    validate_source_services!(non_local_blobs)

    trap("INT") do
      interrupted = true
      $stdout.puts "\nInterrupt received. Finishing current blob..."
    end

    non_local_blobs.find_each(batch_size: 100) do |blob|
      break if interrupted

      result = migrate_blob(blob, disk_service, dry_run:)
      case result
      when :migrated then migrated += 1
      when :skipped then skipped += 1
      when :failed then failed += 1
      end

      print_progress(migrated + skipped + failed, total)
    end

    $stdout.puts ""
    print_summary({ migrated:, skipped:, failed:, interrupted:, dry_run: })

    exit 1 if failed.positive?
  end
end

def resolve_disk_service
  ActiveStorage::Blob.services.fetch(:local)
rescue KeyError
  $stdout.puts "ERROR: No 'local' service configured in config/storage.yml."
  $stdout.puts "Ensure a 'local' entry with 'service: Disk' exists."
  exit 1
end

def configured_service_names
  registry = ActiveStorage::Blob.services
  registry.instance_variable_get(:@configurations).keys.map(&:to_s)
end

def validate_source_services!(blobs)
  service_names = blobs.distinct.pluck(:service_name)
  configured = configured_service_names
  missing = service_names - configured

  return if missing.empty?

  source_override = ENV.fetch("SOURCE_SERVICE", nil)
  if source_override && configured.include?(source_override)
    $stdout.puts "Using SOURCE_SERVICE=#{source_override} to download blobs with service names: #{missing.join(', ')}"
    return
  end

  $stdout.puts "ERROR: Blobs reference service(s) #{missing.map { |s| %("#{s}") }.join(', ')} " \
               "but no matching service is configured in config/storage.yml."
  $stdout.puts ""
  $stdout.puts "Options:"
  $stdout.puts "  1. Add a temporary entry to config/storage.yml for the missing service"
  $stdout.puts "  2. Set SOURCE_SERVICE=<configured_service> to use an existing service"
  $stdout.puts "     (e.g., SOURCE_SERVICE=s3 if your storage.yml 's3' entry points to the same backend)"
  exit 1
end

def resolve_source_service(blob)
  source_override = ENV.fetch("SOURCE_SERVICE", nil)
  service_key = source_override || blob.service_name
  ActiveStorage::Blob.services.fetch(service_key.to_sym)
rescue KeyError
  nil
end

def migrate_blob(blob, disk_service, dry_run:)
  label = "Blob ##{blob.id} (#{blob.filename}, service: #{blob.service_name})"

  if dry_run
    $stdout.puts "  [DRY RUN] Would migrate: #{label}"
    return :migrated
  end

  source_service = resolve_source_service(blob)
  unless source_service
    $stdout.puts "  [SKIP] #{label} — source service not configured"
    return :skipped
  end

  checksum = download_and_verify(blob, source_service)
  return :failed unless checksum

  upload_to_disk(blob, source_service, disk_service)
rescue StandardError => e
  $stdout.puts "  [ERROR] #{label} — #{e.class}: #{e.message}"
  :failed
end

def download_and_verify(blob, source_service)
  label = "Blob ##{blob.id} (#{blob.filename})"
  digester = Digest::MD5.new

  source_service.download(blob.key) do |chunk|
    digester.update(chunk)
  end

  computed_checksum = digester.base64digest
  if computed_checksum != blob.checksum
    $stdout.puts "  [ERROR] #{label} — checksum mismatch (expected: #{blob.checksum}, got: #{computed_checksum})"
    return nil
  end

  computed_checksum
rescue StandardError => e
  $stdout.puts "  [ERROR] #{label} — download failed: #{e.class}: #{e.message}"
  nil
end

def upload_to_disk(blob, source_service, disk_service)
  label = "Blob ##{blob.id} (#{blob.filename})"

  if disk_service.exist?(blob.key)
    $stdout.puts "  [SKIP] #{label} — file already exists on disk, updating service_name only"
    blob.update_column(:service_name, "local") # rubocop:disable Rails/SkipsModelValidations
    return :migrated
  end

  Tempfile.create(["storage_migrate", ".bin"], binmode: true) do |tempfile|
    source_service.download(blob.key) do |chunk|
      tempfile.write(chunk)
    end
    tempfile.rewind

    disk_service.upload(blob.key, tempfile, checksum: blob.checksum)
  end

  blob.update_column(:service_name, "local") # rubocop:disable Rails/SkipsModelValidations
  $stdout.puts "  [OK] #{label}"
  :migrated
rescue StandardError => e
  $stdout.puts "  [ERROR] #{label} — upload failed: #{e.class}: #{e.message}"
  :failed
end

def print_progress(current, total)
  return if total.zero?

  percent = (current.to_f / total * 100).round(1)
  $stdout.print "\rProgress: #{current}/#{total} (#{percent}%)"
end

def print_summary(results)
  $stdout.puts ""
  $stdout.puts "=" * 50
  $stdout.puts "Migration Summary#{' (DRY RUN)' if results[:dry_run]}"
  $stdout.puts "  Migrated: #{results[:migrated]}"
  $stdout.puts "  Skipped:  #{results[:skipped]}"
  $stdout.puts "  Failed:   #{results[:failed]}"
  $stdout.puts "  Status:   #{results[:interrupted] ? 'INTERRUPTED (safe to re-run)' : 'COMPLETE'}"
  $stdout.puts "=" * 50
end
