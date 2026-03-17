# frozen_string_literal: true

# Relaxes Active Storage's checksum requirement for direct uploads of very large
# files (>1 GB by default). Client-side MD5 computation via SparkMD5/FileReader
# silently stalls browsers on files >10-20 GB with no error or progress.
#
# See GitHub issue #747.
#
# TRADE-OFFS:
# - Disk service: `ensure_integrity_of` is skipped when checksum is nil — no
#   digest verification of the uploaded bytes.
# - S3-compatible services: the Content-MD5 header is omitted from the direct
#   upload PUT, so S3 will not verify integrity on receipt.
# - In both cases, silent corruption during network transfer will NOT be detected
#   for large files. If this is unacceptable, add a background job that computes
#   checksums post-upload and flags mismatches.

Rails.application.config.to_prepare do
  # Allow nil checksum on blobs created for direct upload of large files.
  # The original validation is: `validates :checksum, presence: true, unless: :composed`
  # We extend it to also allow nil when `checksum_skipped` metadata is set.
  ActiveStorage::Blob.class_eval do
    # REASONING:
    # - Why: client-side MD5 stalls browsers on very large files (issue #747)
    # - Alternatives considered: computing checksum server-side during upload
    #   (not possible with direct upload to S3), chunked hashing with Web Workers
    #   (complex, still slow for 20+ GB)
    # - Decision: skip checksum for large files, accept integrity trade-off
    # - Performance: no impact — this removes computation, doesn't add any
    # - Future: VerifyChecksumJob computes checksums post-upload for large files
    #
    # NOTE: Do NOT use clear_validators! here — it removes ALL validators on
    # Blob (including service_name presence), not just the checksum one.
    # Instead, target only the checksum validator for removal.
    _validators.delete(:checksum)
    _validate_callbacks.each do |callback|
      next unless callback.filter.is_a?(ActiveModel::Validations::PresenceValidator)
      if callback.filter.attributes == [:checksum]
        _validate_callbacks.delete(callback)
      end
    end

    validates :checksum, presence: true, unless: -> { composed || checksum_skipped? }

    private

    def checksum_skipped?
      metadata&.dig("checksum_skipped") == true
    end
  end

  # Patch S3 service to omit Content-MD5 header when checksum is nil.
  # Without this, `"Content-MD5" => nil` is sent, which S3 rejects as invalid.
  if defined?(ActiveStorage::Service::S3Service)
    ActiveStorage::Service::S3Service.class_eval do
      # REASONING:
      # - Why: nil checksum causes `"Content-MD5" => nil` header, rejected by S3
      # - Alternatives: custom S3 service subclass (more code, harder to maintain)
      # - Decision: patch headers_for_direct_upload to compact nil values
      # - Future: remove if ActiveStorage adds native nil-checksum support
      alias_method :original_headers_for_direct_upload, :headers_for_direct_upload

      def headers_for_direct_upload(key, content_type:, checksum:, **options)
        headers = original_headers_for_direct_upload(key, content_type: content_type, checksum: checksum, **options)
        headers.compact
      end
    end
  end
end
