# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
# - Why: Attack resource files can be 100+ GB. Serving through Puma ties up workers
#   for hours. nginx serves files at wire speed via X-Accel-Redirect.
# - Alternatives: send_file (blocks Puma), redirect to signed URL (requires S3),
#   serve from CDN (not applicable for air-gapped deployments)
# - Decision: X-Accel-Redirect in production, send_file fallback in development
# - Performance: Puma worker freed immediately after auth check
# - Future: add ETag/If-None-Match support for agent caching

class Api::V1::Client::FilesController < Api::V1::BaseController
  ALLOWED_TYPES = %w[WordList RuleList MaskList].freeze

  def show
    resource = find_authorized_resource
    unless resource&.file_path.present? && File.exist?(resource.file_path)
      render json: { error: "File not found" }, status: :not_found
      return
    end

    if nginx_accel_enabled?
      serve_via_nginx(resource)
    else
      send_file resource.file_path,
                filename: resource.file_name,
                type: "application/octet-stream",
                disposition: "attachment"
    end
  end

  private

  def find_authorized_resource
    type_name = params[:type]&.classify
    return nil unless ALLOWED_TYPES.include?(type_name)

    resource_class = type_name.constantize
    resource_class.joins(attacks: :tasks)
                  .where(tasks: { agent: @agent })
                  .find_by(id: params[:id])
  end

  def serve_via_nginx(resource)
    storage_base = ENV.fetch("ATTACK_RESOURCE_STORAGE_PATH", "/data/attack_resources")
    internal_path = resource.file_path.sub(storage_base, "/internal/attack_resources")

    response.headers["X-Accel-Redirect"] = internal_path
    response.headers["Content-Type"] = "application/octet-stream"
    response.headers["Content-Disposition"] = "attachment; filename=\"#{resource.file_name}\""
    head :ok
  end

  def nginx_accel_enabled?
    ENV.fetch("NGINX_ACCEL_ENABLED", Rails.env.production? ? "true" : "false") == "true"
  end
end
