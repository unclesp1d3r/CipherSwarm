# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
# - Why: Files >1 GB skip client-side MD5 checksum to avoid browser stalls (#747).
#   This job computes the checksum server-side post-upload for integrity verification.
# - Alternatives: compute during upload (not possible with S3 direct upload),
#   skip verification entirely (unacceptable — corrupt wordlists waste agent time)
# - Decision: async verification via Sidekiq, flag resources as checksum_verified
# - Performance: reads entire blob once — same cost as CountFileLinesJob
# - Future: could add automatic re-download on mismatch

class VerifyChecksumJob < ApplicationJob
  include TempStorageValidation

  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(resource_id, resource_type)
    resource_class = resource_type.safe_constantize
    raise ArgumentError, "Invalid resource type: #{resource_type}" unless resource_class

    resource = resource_class.find(resource_id)
    blob = resource.file.blob

    unless blob
      Rails.logger.warn { "[ChecksumVerify] No blob found for #{resource_type}##{resource_id}" }
      return
    end

    computed_checksum = compute_checksum(blob)

    if blob.checksum.nil? || blob.metadata&.dig("checksum_skipped")
      backfill_checksum(blob, computed_checksum, resource)
    elsif blob.checksum == computed_checksum
      mark_verified(resource)
    else
      log_mismatch(resource_type, resource_id, blob.checksum, computed_checksum)
    end
  end

  private

  def compute_checksum(blob)
    # Call service.open directly with verify: false — blob.open always
    # passes verify: true (unless composed), which raises IntegrityError
    # when the stored checksum is nil or mismatched.
    blob.service.open(
      blob.key,
      checksum: blob.checksum,
      verify: false,
      name: ["ActiveStorage-#{blob.id}-", blob.filename.extension_with_delimiter]
    ) do |tempfile|
      Digest::MD5.file(tempfile.path).base64digest
    end
  end

  def backfill_checksum(blob, computed_checksum, resource)
    blob.update!(
      checksum: computed_checksum,
      metadata: blob.metadata&.except("checksum_skipped") || {}
    )
    resource.update!(checksum_verified: true)
    Rails.logger.info { "[ChecksumVerify] Computed and saved checksum for #{resource.class.name}##{resource.id}" }
  end

  def mark_verified(resource)
    resource.update!(checksum_verified: true)
    Rails.logger.info { "[ChecksumVerify] Checksum verified for #{resource.class.name}##{resource.id}" }
  end

  def log_mismatch(resource_type, resource_id, expected, computed)
    Rails.logger.warn do
      "[ChecksumMismatch] #{resource_type}##{resource_id} — " \
        "expected #{expected}, computed #{computed}"
    end
  end
end
