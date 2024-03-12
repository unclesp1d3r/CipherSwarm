class ProcessHashListJob < ApplicationJob
  queue_as :default
  retry_on ActiveStorage::FileNotFoundError, wait: 5.seconds, attempts: 3

  def perform(*args)
    id = args.first
    list = HashList.find(id)
    unless list.processed?
      list.file.open do |file|
        file.each_line do |line|
          next if line.blank?
          # Metadata fields are the leading fields in the hash list file that are not the hash value
          #   or the plain text.
          if list.metadata_fields_count == 0 and not list.salt?
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
          HashItem.create!(
            hash_value: hash_value,
            metadata_fields: metadata_fields,
            salt: salt,
            hash_list: list
          )
        end
      end
      list.processed = true
      list.save!
    end
  end
end
