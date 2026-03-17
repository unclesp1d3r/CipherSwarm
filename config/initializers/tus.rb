# frozen_string_literal: true

# REASONING:
# - Why: Active Storage direct uploads stall on files >1-2 GB (#747).
#   tus-ruby-server provides chunked, resumable uploads that handle 100+ GB files.
# - Alternatives: nginx upload module (no resume), Shrine+tus (replaces AS entirely
#   before we're ready), custom chunked upload (reinventing the wheel)
# - Decision: tus-ruby-server with filesystem storage, mounted as Rack app
# - Performance: constant memory usage regardless of file size (streams chunks to disk)
# - Future: can switch to S3 storage backend if needed

require "tus/server"

# Storage: filesystem (local disk). Files are written to the tus data directory
# as chunks, then concatenated on completion.
Tus::Server.opts[:storage] = Tus::Storage::Filesystem.new(
  Rails.root.join(ENV.fetch("TUS_DATA_DIR", "tmp/tus_data")).to_s
)

# Maximum upload size: unlimited (attack resources can be 100+ GB)
Tus::Server.opts[:max_size] = nil

# Expiration: incomplete uploads are deleted after 24 hours
Tus::Server.opts[:expiration_time] = 24 * 60 * 60
