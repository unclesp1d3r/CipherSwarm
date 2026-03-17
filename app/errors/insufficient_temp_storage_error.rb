# frozen_string_literal: true

# Raised when a job detects insufficient temp storage space to download
# an Active Storage blob. Retried with backoff (transient space pressure
# from concurrent jobs) then discarded if space remains unavailable.
class InsufficientTempStorageError < StandardError; end
