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

    upload_id = extract_upload_id(tus_upload_url)

    # Try cached hook data first (set by TusController post-finish hook),
    # fall back to constructing path from upload ID
    cached = Rails.cache.read("tus_upload:#{upload_id}")
    source_path = cached&.dig(:file_path) || File.join(tus_uploads_dir, upload_id)

    # Validate source_path is within the expected tusd uploads directory to prevent path traversal
    validate_source_path!(source_path)

    unless File.exist?(source_path)
      record.destroy! if record.persisted?
      raise TusUploadError, "Upload file not found: #{upload_id}"
    end

    # Use cached filename if available (from tus metadata)
    record.file_name ||= cached&.dig(:filename)

    storage_dir = attack_resource_storage_dir(record)
    FileUtils.mkdir_p(storage_dir)
    dest_filename = "#{record.id}-#{sanitize_filename(record.file_name || 'upload')}"
    dest_path = File.join(storage_dir, dest_filename)

    FileUtils.mv(source_path, dest_path)
    # Also clean up the .info metadata file left by tusd
    info_path = "#{source_path}.info"
    File.delete(info_path) if File.exist?(info_path)

    record.update!(file_path: dest_path, file_size: File.size(dest_path), checksum_verified: false)
    VerifyChecksumJob.perform_later(record.id, record.class.name)
    Rails.cache.delete("tus_upload:#{upload_id}")

    true
  rescue TusUploadError
    raise
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOSPC, IOError => e
    Rails.logger.error("[TusUpload] File system error for #{record.class.name}##{record.id}: " \
                       "#{e.class} - #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    record.destroy! if record.persisted? && record.file_path.blank?
    false
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

  def validate_source_path!(path)
    canonical_source = resolve_path(path)
    return if path_within_dir?(canonical_source, tus_uploads_dir)

    raise TusUploadError, "Path traversal attempt blocked: source path is outside tusd uploads directory"
  rescue Errno::ENOENT
    # File doesn't exist yet — validate the directory component.
    # Fail closed: if we can't resolve directories, reject the path.
    canonical_parent = resolve_path(File.dirname(path))
    return if path_within_dir?(canonical_parent, tus_uploads_dir)

    raise TusUploadError, "Path traversal attempt blocked: source path is outside tusd uploads directory"
  end

  # Returns the canonical absolute path, raising Errno::ENOENT if it does not exist.
  def resolve_path(path)
    File.realpath(File.expand_path(path))
  end

  # Returns true when +child+ is strictly inside +directory+ (not equal to it).
  # Both arguments must already be canonical (use resolve_path first).
  def path_within_dir?(child, directory)
    canonical_dir = resolve_path(directory)
    child.start_with?("#{canonical_dir}/")
  end

  def sanitize_filename(name)
    name.gsub(/[^0-9A-Za-z.\-_]/, "_")
  end
end
