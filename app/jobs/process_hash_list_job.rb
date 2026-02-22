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

    list.file.open do |file|
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

        # Process in batches to avoid memory issues
        if hash_items.size >= batch_size
          process_batch(list, hash_items)
          processed_count += hash_items.size
          hash_items.clear
        end
      end
    end

    # Process remaining items
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
    if defined?(ApplicationConfig) && ApplicationConfig.respond_to?(:hash_list_batch_size)
      return ApplicationConfig.hash_list_batch_size.to_i
    end

    ENV.fetch("HASH_LIST_PROCESS_BATCH_SIZE", "1000").to_i
  end

  # Process a batch of hash items efficiently
  def process_batch(list, hash_items)
    HashItem.transaction do
      # Bulk insert the hash items
      # rubocop:disable Rails/SkipsModelValidations
      # Intentionally skipping validations for performance during bulk insert.
      # Data integrity is enforced by database-level constraints.
      inserted_items = HashItem.insert_all(hash_items, returning: %w[id hash_value])
      # rubocop:enable Rails/SkipsModelValidations

      # Check for already cracked hashes in batch
      hash_values = hash_items.map { |item| item[:hash_value] }
      cracked_hashes = HashItem.includes(:hash_list)
                               .where(hash_value: hash_values, cracked: true, hash_list: { hash_type_id: list.hash_type_id })
                               .index_by(&:hash_value)

      # Update any items that should be marked as cracked
      if cracked_hashes.any?
        updates = []
        inserted_items.each do |inserted|
          if (cracked = cracked_hashes[inserted["hash_value"]])
            updates << {
              id: inserted["id"],
              plain_text: cracked.plain_text,
              cracked: true,
              cracked_time: Time.zone.now,
              attack_id: cracked.attack_id
            }
          end
        end

        updates.each do |attrs|
          # rubocop:disable Rails/SkipsModelValidations
          # Intentionally skipping validations for performance during bulk update of cracked items
          HashItem.where(id: attrs[:id]).update_all(
            plain_text: attrs[:plain_text],
            cracked: attrs[:cracked],
            cracked_time: attrs[:cracked_time],
            attack_id: attrs[:attack_id]
          )
          # rubocop:enable Rails/SkipsModelValidations
        end if updates.any?
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Failed to process batch for list #{list.id}: #{e.message}")
    raise
  end
end
