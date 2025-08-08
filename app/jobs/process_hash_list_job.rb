# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

#
# The ProcessHashListJob class is responsible for processing a HashList identified by a given ID.
# It retrieves the HashList object, checks if it has already been processed, and if not, processes
# each line in the associated file. For each line, it creates a HashItem, validates it, and adds it
# to the HashList. Additionally, it checks if the hash value has already been cracked and updates
# the HashItem accordingly.
#
# The job is configured to retry on specific errors:
# - ActiveStorage::FileNotFoundError: Retries with a polynomially increasing wait time, up to 10 attempts.
# - ActiveRecord::RecordNotFound: Retries with a polynomially increasing wait time, up to 3 attempts.
#
# @param id [Integer] the ID of the HashList to be processed
# @return [void]
# @raise [StandardError] if there is an error during file processing
class ProcessHashListJob < ApplicationJob
  queue_as :ingest
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 10
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 3

  # Performs the processing of a HashList identified by the given ID.
  #
  # This method retrieves the HashList object, checks if it has already been processed,
  # and if not, processes each line in the associated file. For each line, it creates
  # a HashItem, validates it, and adds it to the HashList. Additionally, it checks if
  # the hash value has already been cracked and updates the HashItem accordingly.
  #
  # @param id [Integer] the ID of the HashList to be processed
  # @return [void]
  # @raise [StandardError] if there is an error during file processing
  def perform(id)
    list = HashList.find(id)
    return if list.processed?

    hash_items = []
    processed_count = 0

    list.file.open do |file|
      file.each_line.with_index do |line, index|
        next if line.blank?

        line.strip!
        hash_items << HashItem.new(
          hash_value: line,
          metadata: {},
          hash_list_id: list.id,
          created_at: Time.current,
          updated_at: Time.current,
          cracked: false
        ).attributes

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

    # Mark as processed if we actually ingested items
    if processed_count > 0
      list.update(processed: true)
    else
      Rails.logger.error("No hash items were processed for list #{list.id}")
    end
  end

  private

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
      inserted_items = HashItem.insert_all(hash_items, returning: %w[id hash_value])
      
      # Check for already cracked hashes in batch
      hash_values = hash_items.map { |item| item[:hash_value] }
      cracked_hashes = HashItem.includes(:hash_list)
                              .where(hash_value: hash_values, cracked: true, hash_list: { hash_type_id: list.hash_type_id })
                              .index_by(&:hash_value)

      # Update any items that should be marked as cracked
      if cracked_hashes.any?
        updates = []
        inserted_items.each do |inserted|
          if (cracked = cracked_hashes[inserted['hash_value']])
            updates << {
              id: inserted['id'],
              plain_text: cracked.plain_text,
              cracked: true,
              cracked_time: Time.zone.now,
              attack_id: cracked.attack_id
            }
          end
        end
        
        updates.each do |attrs|
          HashItem.where(id: attrs[:id]).update_all(
            plain_text: attrs[:plain_text],
            cracked: attrs[:cracked],
            cracked_time: attrs[:cracked_time],
            attack_id: attrs[:attack_id]
          )
        end if updates.any?
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to process batch for list #{list.id}: #{e.message}")
    raise
  end
end
