# frozen_string_literal: true

json.extract! attack, :id, :created_at, :updated_at
json.url attack_url(attack, format: :json)
