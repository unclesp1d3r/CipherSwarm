# frozen_string_literal: true

json.extract! cracker_binary, :id, :version, :active, :cracker_id, :created_at, :updated_at
json.url cracker_binary_url(cracker_binary, format: :json)
