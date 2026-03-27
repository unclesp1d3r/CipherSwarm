# frozen_string_literal: true

require "testcontainers"

# TusdHelper manages a tusd container via testcontainers for system tests
# that upload files via tus-js-client. Uses a random mapped port and sets
# TUS_ENDPOINT_URL so the Stimulus controller talks to tusd directly.
#
# Usage in specs:
#   before(:all) { TusdHelper.ensure_tusd_running }
#
# The container is shared across the entire test suite and automatically
# cleaned up when the Ruby process exits (testcontainers lifecycle).
module TusdHelper
  TUSD_IMAGE = "tusproject/tusd:v2"
  TUSD_PORT = 8080

  @mutex = Mutex.new
  @container = nil
  @mapped_port = nil
  @uploads_dir = nil

  module_function

  # Ensures tusd is running and reachable. Starts it if needed.
  # Thread-safe — only one container is started regardless of concurrent calls.
  #
  # Mounts a host-side temp directory into the container so both tusd (inside Docker)
  # and the Rails process (on the host) can access uploaded files at the same path.
  def ensure_tusd_running
    @mutex.synchronize do
      return if @container&.running?

      @uploads_dir = Dir.mktmpdir("tusd-test-uploads")

      @container = Testcontainers::DockerContainer.new(
        TUSD_IMAGE,
        exposed_ports: ["#{TUSD_PORT}/tcp"],
        filesystem_binds: ["#{@uploads_dir}:/srv/tusd-data"],
        command: [
          "-upload-dir=/srv/tusd-data",
          "-base-path=/uploads/",
          "-max-size=0",
          "-cors-allow-origin=.*"
        ]
      )

      @container.start
      @container.wait_for_tcp_port(TUSD_PORT, timeout: 15)
      @mapped_port = @container.mapped_port(TUSD_PORT)

      # Set the endpoint URL so Rails forms point the browser JS to tusd directly
      ENV["TUS_ENDPOINT_URL"] = "http://localhost:#{@mapped_port}/uploads/"
      # Point Rails server-side upload handler to the shared directory
      ENV["TUS_UPLOADS_DIR"] = @uploads_dir

      Rails.logger.info("[TusdHelper] tusd container started on localhost:#{@mapped_port}, uploads at #{@uploads_dir}")
    end
  end

  def mapped_port
    @mapped_port # rubocop:disable ThreadSafety/ClassInstanceVariable -- read-only after mutex-protected write
  end

  def uploads_dir
    @uploads_dir # rubocop:disable ThreadSafety/ClassInstanceVariable -- read-only after mutex-protected write
  end
end
