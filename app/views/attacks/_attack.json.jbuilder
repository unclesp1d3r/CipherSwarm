# frozen_string_literal: true

json.extract! attack, :id, :created_at, :updated_at
json.url campaign_attack_url([attack.campaign, attack], format: :json)
