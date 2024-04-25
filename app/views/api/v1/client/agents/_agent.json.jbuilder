# frozen_string_literal: true

json.extract! agent, :id,
              :name,
              :client_signature,
              :command_parameters,
              :ignore_errors,
              :cpu_only,
              :trusted,
              :operating_system,
              :devices
json.advanced_configuration do
  json.partial! "api/v1/client/agents/advanced_configuration", agent: agent
end
