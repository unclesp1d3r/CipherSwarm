# frozen_string_literal: true

# REASONING:
# - Why: Overrides ActiveStorage::DirectUploadsController to support nil checksum
#   for large-file direct uploads where client-side MD5 stalls the browser.
#   See GitHub issue #747.
# - Alternatives considered: monkey-patching the base controller's blob_args
#   method in an initializer (fragile across Rails upgrades), or computing
#   checksum server-side (not feasible with S3 direct upload).
# - Decision: explicit controller override — clear, testable, upgrade-safe.
# - Performance: no impact.
# - Future: remove if ActiveStorage adds native optional-checksum support.

module ActiveStorage
  class DirectUploadsController < ActiveStorage::BaseController
    def create
      blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
      render json: direct_upload_json(blob)
    end

    private

    def blob_args
      args = params.expect(blob: [:filename, :byte_size, :checksum, :content_type, metadata: {}])
                    .to_h
                    .symbolize_keys

      if args[:checksum].blank?
        args[:checksum] = nil
        args[:metadata] = (args[:metadata] || {}).merge("checksum_skipped" => true)
      end

      args
    end

    def direct_upload_json(blob)
      blob.as_json(root: false, methods: :signed_id).merge(direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      })
    end
  end
end
