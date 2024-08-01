# frozen_string_literal: true

json.extract! agent, :id, :client_signature, :active, :last_ipaddress,
              :last_seen_at, :name, :operating_system, :token, :user_id, :state,
              :created_at, :updated_at
json.url agent_url(agent, format: :json)
