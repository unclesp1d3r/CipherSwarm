# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
# - Why: tus uploads don't include client-side checksums. This job computes
#   the checksum server-side post-upload for integrity verification.
# - Alternatives: compute during upload (tus doesn't support end-to-end checksums),
#   skip verification entirely (unacceptable — corrupt wordlists waste agent time)
# - Decision: async verification via Sidekiq, flag resources as checksum_verified
# - Performance: reads file once from disk via file_path (no tmp download)
# - Future: could add automatic re-download on mismatch

class VerifyChecksumJob < ApplicationJob
  ALLOWED_TYPES = %w[WordList RuleList MaskList].freeze

  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(resource_id, resource_type)
    raise ArgumentError, "Invalid resource type: #{resource_type}" unless ALLOWED_TYPES.include?(resource_type)

    resource = resource_type.constantize.find(resource_id)
    file_path = resolve_file_path(resource)

    unless file_path
      Rails.logger.warn { "[ChecksumVerify] No file found for #{resource_type}##{resource_id}" }
      return
    end

    computed_checksum = Digest::MD5.file(file_path).base64digest

    if resource.checksum.blank?
      resource.update!(checksum: computed_checksum, checksum_verified: true)
      Rails.logger.info { "[ChecksumVerify] Computed and saved checksum for #{resource_type}##{resource_id}" }
    elsif resource.checksum == computed_checksum
      resource.update!(checksum_verified: true)
      Rails.logger.info { "[ChecksumVerify] Checksum verified for #{resource_type}##{resource_id}" }
    else
      resource.update!(checksum_verified: false)
      Rails.logger.error do
        "[ChecksumMismatch] INTEGRITY FAILURE: #{resource_type}##{resource_id} — " \
          "expected #{resource.checksum}, computed #{computed_checksum}. Re-upload recommended."
      end
    end
  end

  private

  def resolve_file_path(resource)
    return resource.file_path if resource.file_path.present? && File.exist?(resource.file_path)

    nil
  end
end
