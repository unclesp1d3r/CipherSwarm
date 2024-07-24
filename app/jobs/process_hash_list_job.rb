# frozen_string_literal: true

class ProcessHashListJob < ApplicationJob
  queue_as :ingest
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 10
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 3

  # Performs the processing of a hash list identified by its ID.
  #
  # @param id [Integer] The ID of the hash list to be processed.
  # @return [void]
  def perform(id)
    list = HashList.find(id)
    return if list.processed?

    list.file.open do |file|
      file.each_line do |line|
        next if line.blank?
        line = line.strip

        # Metadata fields are the leading fields in the hash list file that are not the hash value
        #   or the plain text.
        if list.metadata_fields_count.zero? and !list.salt?
          metadata_fields = []
          hash_value = line
        else
          metadata_fields = line.split(list.separator)[0..list.metadata_fields_count - 1]
          if list.salt?
            salt = line.split(list.separator)[list.metadata_fields_count + 1]
            hash_value = line.split(list.separator)[list.metadata_fields_count + 2]
          else
            salt = nil
            hash_value = line.split(list.separator)[list.metadata_fields_count].chomp!
          end
        end

        hi = HashItem.build(
          hash_value: hash_value,
          metadata_fields: metadata_fields,
          salt: salt,
          hash_list: list
        )
        list.hash_items << hi if hi.valid?
      end
    end

    list.processed = list.hash_items.size.positive?
    Rails.logger.error("Failed to ingest hash items") unless list.save
  end
end
