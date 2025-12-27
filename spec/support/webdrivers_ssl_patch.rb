# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

begin
  require "webdrivers"
rescue LoadError
  # webdrivers gem not available - skip this patch (only needed for system tests)
  return
end

return unless defined?(Webdrivers)

require "net/http"
require "uri"
require "openssl"
require "json"

module Webdrivers
  module NetworkSslPatch
    module_function

    def build_http(uri, verify: true)
      http = if Webdrivers.proxy_addr && Webdrivers.proxy_port
        Net::HTTP.new(
          uri.host,
          uri.port,
          Webdrivers.proxy_addr,
          Webdrivers.proxy_port,
          Webdrivers.proxy_user,
          Webdrivers.proxy_pass
        )
      else
        Net::HTTP.new(uri.host, uri.port)
      end

      http.use_ssl = uri.scheme == "https"
      if http.use_ssl?
        if verify
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.cert_store = build_cert_store
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      http
    end

    def build_cert_store
      OpenSSL::X509::Store.new.tap do |store|
        store.set_default_paths
        system_cert_path = ENV.fetch("SSL_CERT_FILE", nil)
        store.add_file(system_cert_path) if system_cert_path && File.file?(system_cert_path)
      end
    end

    def fetch(url, limit, allow_insecure: false)
      raise Webdrivers::ConnectionError, "Too many HTTP redirects" if limit.zero?

      uri = URI(url)
      response = build_http(uri, verify: !allow_insecure).request(Net::HTTP::Get.new(uri))

      if response.is_a?(Net::HTTPRedirection)
        location = response["location"]
        Webdrivers.logger.debug "Redirected to #{location}"
        fetch(location, limit - 1, allow_insecure: allow_insecure)
      else
        response
      end
    rescue OpenSSL::SSL::SSLError => e
      raise if allow_insecure

      Webdrivers.logger.warn("Retrying #{url} without SSL verification due to: #{e.message}")
      fetch(url, limit, allow_insecure: true)
    rescue SocketError
      raise Webdrivers::ConnectionError, "Can not reach #{url}"
    end
  end

  class Network
    class << self
      prepend(Module.new do
        def get_response(url, limit = 10)
          NetworkSslPatch.fetch(url, limit)
        rescue OpenSSL::SSL::SSLError => e
          Webdrivers.logger.debug("SSL error when fetching #{url}: #{e.message}")
          super
        end
      end)
    end
  end
end

module Webdrivers
  module ChromedriverChromeForTestingPatch
    def latest_point_release(version)
      super
    rescue Webdrivers::VersionError, Webdrivers::NetworkError => error
      fallback = chrome_for_testing_version(version)
      return fallback if fallback

      raise error
    end

    private

    def direct_url(driver_version)
      if (url = chrome_for_testing_downloads[driver_version.to_s])
        Webdrivers.logger.debug("Using Chrome for Testing download URL: #{url}")
        return url
      end

      super
    end

    def chrome_for_testing_version(version)
      milestone = version.respond_to?(:segments) ? version.segments.first.to_s : version.to_s.split(".").first
      response = Network.get(URI("https://googlechromelabs.github.io/chrome-for-testing/latest-versions-per-milestone.json"))
      data = JSON.parse(response)
      candidate = data.dig("milestones", milestone, "version")
      return unless candidate

      candidate_segments = candidate.split(".")[0..2].join(".")
      requested_segments = if version.respond_to?(:segments)
        version.segments[0..2].join(".")
      else
        version.to_s.split(".")[0..2].join(".")
      end

      if candidate_segments == requested_segments
        normalized = normalize_version(candidate)
        remember_chrome_for_testing_download(normalized)
        Webdrivers.logger.warn("Falling back to Chrome for Testing metadata for milestone #{milestone}: #{normalized}")
        normalized
      else
        Webdrivers.logger.debug("Chrome for Testing version #{candidate} does not match requested build #{requested_segments}")
        nil
      end
    rescue StandardError => e
      Webdrivers.logger.debug("Chrome for Testing lookup failed for milestone #{milestone}: #{e.class}: #{e.message}")
      nil
    end

    def remember_chrome_for_testing_download(version)
      chrome_for_testing_downloads[version.to_s] = chrome_for_testing_download_url(version)
    end

    def chrome_for_testing_downloads
      @chrome_for_testing_downloads ||= {}
    end

    def chrome_for_testing_download_url(version)
      platform = chrome_for_testing_platform(version)
      "https://storage.googleapis.com/chrome-for-testing-public/#{version}/#{platform}/chromedriver-#{platform}.zip"
    end

    def chrome_for_testing_platform(version)
      filename = driver_filename(version)

      case filename
      when "mac64"
        "mac-x64"
      when "mac_arm64", "mac64_m1"
        "mac-arm64"
      else
        filename.tr("_", "-")
      end
    end
  end

  class Chromedriver
    class << self
      prepend ChromedriverChromeForTestingPatch
    end
  end
end

module Webdrivers
  module SystemChromeForTestingPatch
    private

    def unzip_file(filename, driver_name)
      super
    rescue Errno::ENOENT, Zip::Error => e
      Webdrivers.logger.debug("Default chromedriver extraction failed: #{e.class}: #{e.message}")
      unless extract_chrome_for_testing_entry(filename, driver_name)
        raise e
      end
    end

    def extract_chrome_for_testing_entry(filename, driver_name)
      Zip::File.open(filename) do |zip_file|
        entry = zip_file.entries.find do |candidate|
          File.basename(candidate.name).start_with?("chromedriver") && !candidate.directory?
        end
        return false unless entry

        target_path = File.join(Dir.pwd, driver_name)
        delete(target_path)
        FileUtils.mkdir_p(File.dirname(target_path)) unless File.exist?(File.dirname(target_path))
        zip_file.extract(entry, target_path)
      end

      driver_name
    rescue StandardError => e
      Webdrivers.logger.debug("Chrome for Testing unzip fallback failed: #{e.class}: #{e.message}")
      false
    end
  end

  class System
    class << self
      prepend SystemChromeForTestingPatch
    end
  end
end
