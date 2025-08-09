# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! agent, :id, :client_signature, :active, :last_ipaddress,
              :last_seen_at, :name, :host_name, :operating_system, :token, :user_id, :state,
              :created_at, :updated_at
json.url agent_url(agent, format: :json)
