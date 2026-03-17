# frozen_string_literal: true

# REASONING:
# - Why: tus-ruby-server stores completed uploads in a temp directory. This concern
#   moves them to permanent storage and sets file_path on the record.
# - Alternatives: tus after_finish hook (runs outside request context, no access to
#   model), Active Storage attach (defeats the purpose of removing AS)
# - Decision: controller concern called during create/update actions
# - Performance: FileUtils.mv is O(1) on same filesystem, no data copying
# - Future: could add virus scanning hook before move

module TusUploadHandler
  extend ActiveSupport::Concern

  private

  def process_tus_upload(record, tus_upload_url)
    return if tus_upload_url.blank?

    source_path = tus_file_path(tus_upload_url)
    unless source_path && File.exist?(source_path)
      Rails.logger.error("[TusUpload] File not found for #{record.class.name}##{record.id}")
      return false
    end

    storage_dir = attack_resource_storage_dir(record)
    FileUtils.mkdir_p(storage_dir)
    dest_filename = "#{record.id}-#{sanitize_filename(record.file_name || 'upload')}"
    dest_path = File.join(storage_dir, dest_filename)

    FileUtils.mv(source_path, dest_path)
    record.update!(file_path: dest_path, file_size: File.size(dest_path), checksum_verified: false)

    # Enqueue deferred checksum verification
    VerifyChecksumJob.perform_later(record.id, record.class.name)

    true
  rescue StandardError => e
    Rails.logger.error("[TusUpload] Failed to process upload for #{record.class.name}##{record.id}: #{e.message}")
    false
  end

  def process_tus_upload_for_hash_list(hash_list, tus_upload_url)
    return if tus_upload_url.blank?

    source_path = tus_file_path(tus_upload_url)
    unless source_path && File.exist?(source_path)
      Rails.logger.error("[TusUpload] File not found for HashList##{hash_list.id}")
      return false
    end

    hash_list.update!(temp_file_path: source_path)
    true
  end

  def tus_file_path(tus_upload_url)
    return nil if tus_upload_url.blank?

    upload_id = tus_upload_url.split("/").last
    tus_data_dir = Rails.root.join(ENV.fetch("TUS_DATA_DIR", "tmp/tus_data")).to_s
    File.join(tus_data_dir, upload_id)
  end

  def attack_resource_storage_dir(record)
    base = ENV.fetch("ATTACK_RESOURCE_STORAGE_PATH",
                     Rails.root.join("storage/attack_resources").to_s)
    type_dir = record.class.name.underscore.pluralize
    File.join(base, type_dir)
  end

  def sanitize_filename(name)
    name.gsub(/[^0-9A-Za-z.\-_]/, "_")
  end
end
