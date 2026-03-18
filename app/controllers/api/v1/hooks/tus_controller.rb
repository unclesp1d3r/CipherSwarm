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
  # POST /api/v1/hooks/tus
  # Called by tusd internally when upload completes (post-finish event).
  # NOT authenticated via agent/session — tusd calls from the backend network.
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
end
