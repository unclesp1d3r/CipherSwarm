# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
# This module encapsulates the storage migration logic to avoid polluting the global
# namespace with generic method names (e.g., print_progress, print_summary).
# It provides a single-pass download that simultaneously verifies checksums and writes
# to disk, preventing the data integrity gap of a double-download approach.
module StorageMigration # rubocop:disable Metrics/ModuleLength
  module_function

  def run
    migrated = 0
    skipped = 0
    failed = 0
    interrupted = false

    disk_service = resolve_disk_service
    non_local_blobs = ActiveStorage::Blob.where.not(service_name: "local")

    total = non_local_blobs.count
    dry_run = ENV["DRY_RUN"].present?

    log "Storage Migration: S3/MinIO → Local Disk"
    log "=" * 50
    log "Mode: #{dry_run ? 'DRY RUN (no changes will be made)' : 'LIVE'}"
    log "Total blobs to process: #{total}"
    log "=" * 50

    if total.zero?
      log "No blobs to migrate. All files are already on local storage."
      return true
    end

    validate_source_services!(non_local_blobs)

    trap("INT") do
      interrupted = true
      log "\nInterrupt received. Finishing current blob..."
    end

    non_local_blobs.find_each(batch_size: 100) do |blob|
      break if interrupted

      result = migrate_blob(blob, disk_service, dry_run:)
      migrated += 1 if result == :migrated || result == :would_migrate
      skipped += 1 if result == :skipped
      failed += 1 if result == :failed

      print_progress(migrated + skipped + failed, total)
    end

    $stdout.puts ""
    print_summary({ migrated:, skipped:, failed:, interrupted:, dry_run: })

    !failed.positive? && !interrupted
  end

  def resolve_disk_service
    ActiveStorage::Blob.services.fetch(:local)
  rescue KeyError
    log "ERROR: No 'local' service configured in config/storage.yml."
    log "Ensure a 'local' entry with 'service: Disk' exists."
    abort "[StorageMigration] Missing local disk service configuration"
  end

  def configured_service_names
    registry = ActiveStorage::Blob.services
    configurations = registry.instance_variable_get(:@configurations)
    unless configurations.respond_to?(:keys)
      log "WARNING: Unable to introspect ActiveStorage service registry."
      log "Skipping source service validation. Set SOURCE_SERVICE if needed."
      Rails.logger.warn("[StorageMigration] Cannot read @configurations from " \
                        "ActiveStorage::Service::Registry — internal API may have changed.")
      return []
    end
    configurations.keys.map(&:to_s)
  end

  def validate_source_services!(blobs)
    service_names = blobs.distinct.pluck(:service_name)
    configured = configured_service_names
    missing = service_names - configured

    return if missing.empty?

    source_override = ENV.fetch("SOURCE_SERVICE", nil)
    if source_override && configured.include?(source_override)
      log "Using SOURCE_SERVICE=#{source_override} to download blobs " \
          "with service names: #{missing.join(', ')}"
      return
    end

    log "ERROR: Blobs reference service(s) #{missing.map { |s| %("#{s}") }.join(', ')} " \
        "but no matching service is configured in config/storage.yml."
    log ""
    log "Options:"
    log "  1. Add a temporary entry to config/storage.yml for the missing service"
    log "  2. Set SOURCE_SERVICE=<configured_service> to use an existing service"
    log "     (e.g., SOURCE_SERVICE=s3 if your storage.yml 's3' entry points to the same backend)"
    abort "[StorageMigration] Missing source service configuration"
  end

  def resolve_source_service(blob)
    source_override = ENV.fetch("SOURCE_SERVICE", nil)
    service_key = source_override || blob.service_name
    ActiveStorage::Blob.services.fetch(service_key.to_sym)
  rescue KeyError
    nil
  end

  def migrate_blob(blob, disk_service, dry_run:)
    label = blob_label(blob)

    if dry_run
      log "  [DRY RUN] Would migrate: #{label}"
      return :would_migrate
    end

    source_service = resolve_source_service(blob)
    unless source_service
      log "  [SKIP] #{label} — source service not configured"
      return :skipped
    end

    if disk_service.exist?(blob.key)
      log "  [SKIP] #{label} — file already exists on disk, updating service_name only"
      blob.update_column(:service_name, "local") # rubocop:disable Rails/SkipsModelValidations
      return :migrated
    end

    download_verify_and_upload(blob, source_service, disk_service)
  rescue Errno::ENOSPC
    log "  [FATAL] #{label} — disk full. Cannot continue migration."
    log "  Free disk space and re-run the task."
    Rails.logger.error("[StorageMigration] Disk full during migration of #{label}")
    abort "[StorageMigration] Disk full"
  rescue Errno::EACCES, Errno::EPERM => e
    log "  [FATAL] #{label} — permission denied: #{e.message}"
    log "  Check file permissions on the storage directory."
    Rails.logger.error("[StorageMigration] Permission error: #{e.message}")
    abort "[StorageMigration] Permission denied"
  rescue StandardError => e
    log "  [ERROR] #{label} — #{e.class}: #{e.message}"
    Rails.logger.error("[StorageMigration] #{label} — #{e.class}: #{e.message}" \
                       "\n#{Array(e.backtrace).first(5).join("\n")}")
    :failed
  end

  def download_verify_and_upload(blob, source_service, disk_service)
    label = blob_label(blob)

    Tempfile.create(["storage_migrate", ".bin"], binmode: true) do |tempfile|
      digester = Digest::MD5.new

      source_service.download(blob.key) do |chunk|
        tempfile.write(chunk)
        digester.update(chunk)
      end

      computed_checksum = digester.base64digest
      if computed_checksum != blob.checksum
        log "  [ERROR] #{label} — checksum mismatch " \
            "(expected: #{blob.checksum}, got: #{computed_checksum})"
        Rails.logger.error("[StorageMigration] Checksum mismatch for #{label}")
        return :failed
      end

      tempfile.rewind
      disk_service.upload(blob.key, tempfile, checksum: blob.checksum)
    end

    blob.update_column(:service_name, "local") # rubocop:disable Rails/SkipsModelValidations
    log "  [OK] #{label}"
    :migrated
  end

  def blob_label(blob)
    "Blob ##{blob.id} (#{blob.filename}, service: #{blob.service_name})"
  end

  def print_progress(current, total)
    return if total.zero?

    percent = (current.to_f / total * 100).round(1)
    $stdout.print "\rProgress: #{current}/#{total} (#{percent}%)"
  end

  def print_summary(results)
    label = results[:dry_run] ? "Would migrate" : "Migrated"
    status = results[:interrupted] ? "INTERRUPTED (safe to re-run)" : "COMPLETE"

    log ""
    log "=" * 50
    log "Migration Summary#{' (DRY RUN)' if results[:dry_run]}"
    log "  #{label}: #{results[:migrated]}"
    log "  Skipped:  #{results[:skipped]}"
    log "  Failed:   #{results[:failed]}"
    log "  Status:   #{status}"
    log "=" * 50

    Rails.logger.info("[StorageMigration] Complete: #{label.downcase}=#{results[:migrated]} " \
                      "skipped=#{results[:skipped]} failed=#{results[:failed]} " \
                      "interrupted=#{results[:interrupted]}")
  end

  def log(message)
    $stdout.puts message
  end
end

namespace :storage do
  desc "Migrate files from S3/MinIO to local disk storage"
  task migrate_to_local: :environment do
    success = StorageMigration.run
    exit 1 unless success
  end
end
