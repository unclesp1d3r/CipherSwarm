# frozen_string_literal: true

json.extract! cracker_binary, :id, :version, :active
json.download_url rails_blob_url(cracker_binary.archive_file)
json.checksum cracker_binary.archive_file.checksum
json.binary_file_name cracker_binary.archive_file.filename
json.operating_systems cracker_binary.operating_systems.map(&:name)
