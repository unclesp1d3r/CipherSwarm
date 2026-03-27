# frozen_string_literal: true

# REASONING:
# - Why: tusd (Go sidecar) handles chunked uploads. After upload completes,
#   tusd sends a post-finish hook to Rails which caches upload metadata.
#   This concern moves the completed file to permanent storage and sets file_path.
# - Alternatives: move file in the hook controller (couples hook to model logic),
#   Active Storage attach (defeats the purpose of removing AS)
# - Decision: controller concern called during create/update actions
# - Performance: FileUtils.mv is O(1) on same filesystem, no data copying
# - Future: could add virus scanning hook before move

module TusUploadHandler
  extend ActiveSupport::Concern

  # Raised when tus upload processing fails
  class TusUploadError < StandardError; end

  private

  def process_tus_upload(record, tus_upload_url)
    return if tus_upload_url.blank?

    result = retrieve_and_move_upload(tus_upload_url, record) do |cached|
      record.file_name ||= cached&.dig(:filename)
      attack_resource_storage_dir(record)
    end

    record.update!(file_path: result[:dest_path], file_size: File.size(result[:dest_path]), checksum_verified: false)

    if record.respond_to?(:line_count)
      CountFileLinesJob.perform_later(record.id, record.class.name)
      Rails.logger.info("[TusUpload] Enqueued CountFileLinesJob for #{record.class.name}##{record.id}")
    end

    VerifyChecksumJob.perform_later(record.id, record.class.name)

    true
  rescue TusUploadError
    raise
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOSPC, IOError => e
    log_tus_filesystem_error(record, e)
    record.destroy! if record.persisted? && record.file_path.blank?
    false
  end

  # Processes a tus upload for HashList records. Sets temp_file_path (not file_path)
  # because hash lists are ingested into hash_items rows by ProcessHashListJob,
  # not served directly to agents like attack resources.
  def process_tus_hash_list_upload(record, tus_upload_url)
    return if tus_upload_url.blank?

    result = retrieve_and_move_upload(tus_upload_url, record) do |_cached|
      hash_list_staging_dir
    end

    record.update!(temp_file_path: result[:dest_path], processed: false)

    ProcessHashListJob.perform_later(record.id)
    Rails.logger.info("[TusUpload] Enqueued ProcessHashListJob for HashList##{record.id}")

    true
  rescue TusUploadError
    raise
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOSPC, IOError => e
    log_tus_filesystem_error(record, e)
    record.destroy! if record.persisted? && record.temp_file_path.blank?
    false
  end

  # Retrieves a tus upload, validates source, and moves to destination.
  # Block receives cached metadata and must return the target storage directory.
  def retrieve_and_move_upload(tus_upload_url, record)
    upload_id = extract_upload_id(tus_upload_url)

    cached = Rails.cache.read("tus_upload:#{upload_id}")
    source_path = cached&.dig(:file_path) || File.join(tus_uploads_dir, upload_id)

    validate_source_path!(source_path)

    unless File.exist?(source_path)
      record.destroy! if record.persisted?
      raise TusUploadError, "Upload file not found: #{upload_id}"
    end

    storage_dir = yield(cached)
    FileUtils.mkdir_p(storage_dir)
    filename = cached&.dig(:filename) || record.try(:file_name) || record.try(:name) || "upload"
    dest_filename = "#{record.id}-#{sanitize_filename(filename)}"
    dest_path = File.join(storage_dir, dest_filename)

    FileUtils.mv(source_path, dest_path)
    cleanup_tus_metadata(source_path, upload_id)

    { upload_id: upload_id, dest_path: dest_path }
  end

  def extract_upload_id(url)
    id = url.to_s.split("/").last.to_s.split("?").first
    unless id.present? && id.match?(/\A[a-f0-9]+\z/i)
      raise TusUploadError, "Invalid upload ID format: #{id}"
    end
    id
  end

  def tus_uploads_dir
    ENV.fetch("TUS_UPLOADS_DIR", "/srv/tusd-data")
  end

  def attack_resource_storage_dir(record)
    base = ENV.fetch("ATTACK_RESOURCE_STORAGE_PATH",
                     Rails.root.join("storage/attack_resources").to_s)
    type_dir = record.class.name.underscore.pluralize
    File.join(base, type_dir)
  end

  def hash_list_staging_dir
    base = ENV.fetch("ATTACK_RESOURCE_STORAGE_PATH",
                     Rails.root.join("storage/attack_resources").to_s)
    File.join(base, "hash_lists_staging")
  end

  def validate_source_path!(path)
    resolved = File.realpath(File.expand_path(path))
    return if resolved.start_with?("#{File.realpath(tus_uploads_dir)}/")

    raise TusUploadError, "Path traversal attempt blocked: source path is outside tusd uploads directory"
  rescue Errno::ENOENT
    # File doesn't exist yet — validate the directory component. Fail closed.
    parent = File.realpath(File.expand_path(File.dirname(path)))
    return if parent.start_with?("#{File.realpath(tus_uploads_dir)}/")

    raise TusUploadError, "Path traversal attempt blocked: source path is outside tusd uploads directory"
  end

  def sanitize_filename(name) = name.gsub(/[^0-9A-Za-z.\-_]/, "_")

  def cleanup_tus_metadata(source_path, upload_id)
    File.delete("#{source_path}.info") if File.exist?("#{source_path}.info")
    Rails.cache.delete("tus_upload:#{upload_id}")
  end

  def log_tus_filesystem_error(record, error)
    Rails.logger.error("[TusUpload] File system error for #{record.class.name}##{record.id}: " \
                       "#{error.class} - #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}")
  end
end
