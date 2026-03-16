# frozen_string_literal: true

# REASONING:
#   Why: Background jobs that call blob.open download the entire file to Dir.tmpdir
#     before processing. In Docker containers with tmpfs mounts, this can exhaust
#     available space. Checking before download prevents mid-transfer ENOSPC failures
#     and provides clear, actionable error messages for operators.
#   Alternatives Considered:
#     1) Inline check in each job: duplicates the same 5 lines across 3 jobs.
#     2) ApplicationJob base method: concern is more explicit about opt-in semantics.
#     3) Middleware: too broad — not all jobs download blobs.
#   Decision: ActiveSupport::Concern keeps the check co-located with jobs that need it
#     and follows the existing pattern (see AttackPreemptionLoop).
#   Performance: One stat() syscall per check — negligible.
#   Future: Could add a configurable headroom multiplier if operators want a safety margin.

require "sys/filesystem"

module TempStorageValidation
  extend ActiveSupport::Concern

  private

  # Checks that Dir.tmpdir has more space than the blob requires.
  # Raises InsufficientTempStorageError if space is insufficient.
  # Rescues filesystem stat errors to avoid blocking jobs when the
  # check itself fails (e.g., permission issues, unsupported FS).
  #
  # @param attachment [ActiveStorage::Attached::One] the file attachment to check
  # @raise [InsufficientTempStorageError] if available space <= blob byte_size
  def ensure_temp_storage_available!(attachment)
    blob = attachment.blob
    return if blob.nil?

    stat = Sys::Filesystem.stat(Dir.tmpdir)
    available = stat.bytes_available

    return if available > blob.byte_size

    raise InsufficientTempStorageError,
      "[TempStorage] Not enough temp storage to download #{blob.filename} " \
      "(#{blob.byte_size} bytes required, #{available} bytes available in #{Dir.tmpdir})"
  rescue Sys::Filesystem::Error => e
    Rails.logger.warn(
      "[TempStorage] Could not check available temp storage: #{e.message}. " \
      "Proceeding with download anyway."
    )
  end
end
