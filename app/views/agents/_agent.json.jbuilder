# frozen_string_literal: true

json.extract! agent, :id, :client_signature, :command_parameters,
              :cpu_only, :ignore_errors, :active, :trusted, :last_ipaddress, :last_seen_at,
              :name, :operating_system, :token, :user_id, :created_at, :updated_at
json.url agent_url(agent, format: :json)
