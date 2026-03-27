# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The ProcessHashListJob class is responsible for processing a HashList identified by a given ID.
# It retrieves the HashList object, checks if it has already been processed, and if not,
# bulk-inserts hash items from the associated file in batches (bypassing model validations
# for performance). Additionally, it checks if any hash values have already been cracked
# in other lists of the same hash type and marks them accordingly.
#
# An atomic lock pattern (`UPDATE ... WHERE processed=false`) prevents duplicate processing
# when the after_commit callback fires multiple times. If ingestion fails partway through,
# already-inserted items are cleaned up before retrying to prevent duplicates.
#
# The job is configured to retry on specific errors:
# - ActiveStorage::FileNotFoundError: Retries with a polynomially increasing wait time, up to 10 attempts.
#
# Discards:
# - ActiveRecord::RecordNotFound: Discards the job if the record no longer exists.
#
# @param id [Integer] the ID of the HashList to be processed
# @return [void]
# @raise [ActiveRecord::RecordNotSaved] if the hash list record disappears during processing
# @raise [StandardError] if no hash items were processed from the file
class ProcessHashListJob < ApplicationJob
  include TempStorageValidation

  queue_as :ingest
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 10
  discard_on ActiveRecord::RecordNotFound

  # REASONING:
  #   Use an atomic UPDATE ... WHERE processed = false to prevent duplicate ingestion
  #   when after_commit fires twice (record save + attachment commit).
  # Alternatives Considered:
  #   1) Advisory locks (pg_try_advisory_lock) — adds complexity, requires explicit release.
  #   2) Separate processing_state/claimed_at column — cleaner semantics but requires migration.
  #   3) Redis lock — adds external dependency for a DB-level concern.
  # Decision:
  #   Atomic update keeps overhead low (one extra UPDATE) without long-lived locks.
  # Performance Implications:
  #   One extra UPDATE per job; no row lock held during ingestion.
  # Future Considerations:
  #   Add a processing_state/claimed_at TTL to recover from hard crashes (OOM/deploy kill).

  # Processes the HashList with the given ID. See class documentation for details.
  def perform(id)
    list = HashList.find(id)
    return if list.processed?

    # Acquire an atomic lock to prevent duplicate processing from concurrent jobs.
    # The after_commit callback can fire multiple times (record save + attachment commit),
    # causing two jobs to race. This UPDATE ... WHERE atomically claims the work.
    # rubocop:disable Rails/SkipsModelValidations
    rows_claimed = HashList.where(id: id, processed: false)
                           .update_all(processed: true)
    # rubocop:enable Rails/SkipsModelValidations
    return if rows_claimed.zero?

    ingest_hash_items(list)
  rescue StandardError
    # Roll back the processed flag so the job can be retried.
    # Wrapped in its own rescue to ensure the original exception always propagates.
    begin
      # rubocop:disable Rails/SkipsModelValidations
      HashList.where(id: id).update_all(processed: false)
      # rubocop:enable Rails/SkipsModelValidations
    rescue StandardError => rollback_error
      Rails.logger.error("[ProcessHashList] Failed to roll back processed flag for list #{id}: #{rollback_error.message}")
    end
    raise
  end

  private

  def ingest_hash_items(list)
    # Clean up any partial results from a prior failed attempt to ensure idempotent ingestion.
    list.hash_items.delete_all

    hash_items = []
    processed_count = 0

    open_hash_list_file(list) do |file|
      file.each_line do |line|
        next if line.blank?

        line = line.strip
        hash_items << {
          hash_value: line,
          metadata: {},
          hash_list_id: list.id,
          created_at: Time.current,
          updated_at: Time.current,
          cracked: false
        }

        if hash_items.size >= batch_size
          process_batch(list, hash_items)
          processed_count += hash_items.size
          hash_items.clear
        end
      end
    end

    if hash_items.any?
      process_batch(list, hash_items)
      processed_count += hash_items.size
    end

    # Update the hash items count now that processing is complete.
    # The `processed` flag was already set atomically at the start to prevent duplicates.
    if processed_count.positive?
      # rubocop:disable Rails/SkipsModelValidations
      # Intentionally skipping validations for performance during bulk status update
      affected_rows = HashList.where(id: list.id).update_all(
        hash_items_count: processed_count
      )
      # rubocop:enable Rails/SkipsModelValidations

      if affected_rows.zero?
        error_msg = "[ProcessHashList] Failed to update hash list #{list.id} count - record may have been deleted"
        Rails.logger.error(error_msg)
        raise ActiveRecord::RecordNotSaved, error_msg
      end

      Rails.logger.info("[ProcessHashList] Successfully processed #{processed_count} hash items for list #{list.id}")
    else
      error_msg = "[ProcessHashList] No hash items were processed for list #{list.id}"
      Rails.logger.error(error_msg)
      raise StandardError, error_msg
    end
  end

  # Returns the batch size for processing hash items.
  # Priority order:
  # 1) ApplicationConfig.hash_list_batch_size (if available)
  # 2) ENV["HASH_LIST_PROCESS_BATCH_SIZE"]
  # 3) Default: 1000
  def batch_size
    @batch_size ||= begin
      raw = if defined?(ApplicationConfig) && ApplicationConfig.respond_to?(:hash_list_batch_size)
              ApplicationConfig.hash_list_batch_size
      else
              ENV.fetch("HASH_LIST_PROCESS_BATCH_SIZE", "1000")
      end

      size = Integer(raw, exception: false)
      unless size&.positive?
        raise ArgumentError,
          "[ProcessHashList] Invalid batch_size #{raw.inspect} — must be a positive integer. " \
          "Check ApplicationConfig.hash_list_batch_size or HASH_LIST_PROCESS_BATCH_SIZE env var."
      end

      size
    end
  end

  def process_batch(list, hash_items)
    HashItem.transaction do
      # rubocop:disable Rails/SkipsModelValidations
      # Intentionally skipping validations for performance during bulk insert/upsert.
      # Data integrity is enforced by database-level constraints.
      inserted_items = HashItem.insert_all(hash_items, returning: %w[id hash_value])

      hash_values = hash_items.map { |item| item[:hash_value] }

      # REASONING:
      #   Use joins/pluck instead of includes/index_by to avoid allocating full
      #   HashItem and HashList ActiveRecord objects for every matching row.
      # Alternatives Considered:
      #   1) select + index_by — still instantiates AR objects with reduced columns.
      #   2) find_each — sequential iteration, no batch benefit here.
      # Decision:
      #   pluck returns raw arrays; memory usage is O(matched rows × 3 scalars)
      #   rather than O(matched rows × full AR object graph).
      # Performance Implications:
      #   Eliminates AR object instantiation and association eager-loading per batch;
      #   memory bounded by batch_size rather than total file size.
      # Future Considerations:
      #   If the cracked-hash lookup needs additional columns, add them to the
      #   pluck list and destructure accordingly.
      cracked_hashes = HashItem.joins(:hash_list)
                               .where(hash_value: hash_values, cracked: true, hash_lists: { hash_type_id: list.hash_type_id })
                               .pluck(:hash_value, :plain_text, :attack_id)
                               .each_with_object({}) { |(hv, pt, aid), acc| acc[hv] = [pt, aid] }

      if cracked_hashes.any?
        now = Time.current
        updates = []
        inserted_items.each do |inserted|
          if (cracked = cracked_hashes[inserted["hash_value"]])
            plain_text, attack_id = cracked
            # All NOT NULL columns required in payload — PG evaluates the INSERT side
            # before ON CONFLICT activates (see GOTCHAS.md § upsert_all).
            updates << {
              id: inserted["id"],
              hash_list_id: list.id,
              hash_value: inserted["hash_value"],
              metadata: {},
              created_at: now,
              updated_at: now,
              plain_text: plain_text,
              cracked: true,
              cracked_time: now,
              attack_id: attack_id
            }
          end
        end

        # Intentionally skipping validations for performance during bulk update of cracked items.
        # Note: Do NOT add :updated_at to update_only — Rails 8.1+ auto-manages it
        # via CURRENT_TIMESTAMP on conflict (see GOTCHAS.md).
        if updates.any?
          HashItem.upsert_all(
            updates,
            unique_by: :id,
            update_only: %i[plain_text cracked cracked_time attack_id]
          )
        end
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Failed to process batch for list #{list.id}: #{e.message}")
    raise
  end

  # Opens the hash list file from temp_file_path (tus) or Active Storage (fallback).
  # Deletes the temp file after processing when using tus upload path.
  def open_hash_list_file(list, &)
    if list.temp_file_path.present? && File.exist?(list.temp_file_path)
      File.open(list.temp_file_path, &)
      # Clean up temp file after successful processing — failure must not abort ingestion
      begin
        File.delete(list.temp_file_path) if File.exist?(list.temp_file_path)
        list.update_column(:temp_file_path, nil) # rubocop:disable Rails/SkipsModelValidations -- intentional: avoid callbacks after processing
      rescue StandardError => e
        Rails.logger.warn("[ProcessHashList] Temp file cleanup failed for HashList##{list.id}: #{e.message}")
      end
    elsif list.file.attached?
      ensure_temp_storage_available!(list.file)
      list.file.open(&)
    else
      raise StandardError, "[ProcessHashList] No file found for HashList##{list.id}"
    end
  end
end
