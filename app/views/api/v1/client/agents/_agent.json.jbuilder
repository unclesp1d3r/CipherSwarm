# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! agent, :id,
              :host_name,
              :client_signature,
              :operating_system,
              :state,
              :devices
json.advanced_configuration do
  json.partial! "api/v1/client/agents/advanced_configuration", agent: agent
end
