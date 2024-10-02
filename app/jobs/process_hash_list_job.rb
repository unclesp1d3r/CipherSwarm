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

    HashList.transaction do
      list.file.open do |file|
        file.each_line do |line|
          next if line.blank?

          line.strip!
          hi = HashItem.build(hash_value: line, metadata: {}, hash_list: list)
          list.hash_items << hi if hi.valid?

          cracked_hash = HashItem.includes(:hash_list)
                                 .where(hash_value: line, cracked: true, hash_list: { hash_type_id: list.hash_type_id })
                                 .first
          if cracked_hash
            cracked = hi.update(plain_text: cracked_hash.plain_text, cracked: true, cracked_time: Time.zone.now, attack: cracked_hash.attack)
            Rails.logger.error("Found a cracked hash: #{cracked_hash.hash_value}, but failed to update hash item") unless cracked
          end
        end
      end

      list.processed = true if list.hash_items.any?
      Rails.logger.error("Failed to ingest hash items") unless list.save
    end
  end
end
