# frozen_string_literal: true

# TusdHelper manages a tusd container via testcontainers for system tests
# that upload files via tus-js-client. Uses a random mapped port and sets
# TUS_ENDPOINT_URL so the Stimulus controller talks to tusd directly.
#
# Usage in specs:
#   before(:all) { TusdHelper.ensure_tusd_running }
#
# The container and host-side temp directory are cleaned up via at_exit.
# testcontainers gem is lazy-loaded so non-system test runs skip the dependency.
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
    require "testcontainers" unless defined?(Testcontainers)

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

      at_exit { cleanup }

      Rails.logger.info("[TusdHelper] tusd container started on localhost:#{@mapped_port}, uploads at #{@uploads_dir}")
    rescue StandardError => e
      # Clean up partial state so retry is possible
      @container&.stop rescue nil
      FileUtils.rm_rf(@uploads_dir) if @uploads_dir
      @container = nil
      @mapped_port = nil
      @uploads_dir = nil
      raise "[TusdHelper] Failed to start tusd container: #{e.message}. " \
            "Ensure Docker is running and the image #{TUSD_IMAGE} is available. " \
            "For air-gapped environments, pre-pull with: docker pull #{TUSD_IMAGE}"
    end
  end

  # rubocop:disable ThreadSafety/ClassInstanceVariable -- called from at_exit after mutex-protected setup
  def cleanup
    @container&.stop
  rescue StandardError
    # Best-effort container cleanup
  ensure
    FileUtils.rm_rf(@uploads_dir) if @uploads_dir
    ENV.delete("TUS_ENDPOINT_URL")
    ENV.delete("TUS_UPLOADS_DIR")
  end
  # rubocop:enable ThreadSafety/ClassInstanceVariable

  def mapped_port
    @mapped_port # rubocop:disable ThreadSafety/ClassInstanceVariable -- read-only after mutex-protected write
  end

  def uploads_dir
    @uploads_dir # rubocop:disable ThreadSafety/ClassInstanceVariable -- read-only after mutex-protected write
  end
end
