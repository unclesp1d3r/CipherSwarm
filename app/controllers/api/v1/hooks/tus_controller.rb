# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
# - Why: tusd (Go sidecar) sends HTTP POST hooks when uploads complete.
#   This endpoint receives the post-finish hook and caches upload metadata
#   so the form controller can locate and move the file.
# - Alternatives: tusd file hooks (shell scripts — fragile), tusd gRPC hooks
#   (overkill), direct file path from tus URL (requires path guessing)
# - Decision: HTTP hook to Rails with Redis cache for metadata handoff
# - Performance: single POST per upload, no file I/O — just cache write
# - Future: could add pre-create hook for authentication/authorization

class Api::V1::Hooks::TusController < ActionController::API
  before_action :verify_tusd_origin

  # POST /api/v1/hooks/tus
  # Called by tusd internally when upload completes (post-finish event).
  # Authenticated via shared secret header (TUSD_HOOK_SECRET env var).
  def create
    payload = JSON.parse(request.body.read)
    return head :ok unless payload["Type"] == "post-finish"

    upload = payload.dig("Event", "Upload")
    return head :bad_request unless upload

    upload_id = upload["ID"]
    metadata = upload["MetaData"] || {}
    file_path = upload.dig("Storage", "Path")
    file_size = upload["Size"]

    Rails.cache.write(
      "tus_upload:#{upload_id}",
      { file_path: file_path, file_size: file_size, filename: metadata["filename"] },
      expires_in: 1.hour
    )

    Rails.logger.info { "[TusHook] Upload complete: #{upload_id} (#{file_size} bytes, #{metadata['filename']})" }
    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error("[TusHook] Invalid JSON payload: #{e.message}")
    head :bad_request
  end

  private

  def verify_tusd_origin
    expected = ENV.fetch("TUSD_HOOK_SECRET", nil)
    if expected.blank?
      if Rails.env.production?
        Rails.logger.error("[TusHook] TUSD_HOOK_SECRET is not configured — rejecting all hook requests in production")
        head :unauthorized
      end
      return
    end

    provided = request.headers["X-Tusd-Hook-Secret"].to_s
    return if ActiveSupport::SecurityUtils.secure_compare(expected, provided)

    Rails.logger.warn("[TusHook] Unauthorized hook request from #{request.remote_ip}")
    head :unauthorized
  end
end
