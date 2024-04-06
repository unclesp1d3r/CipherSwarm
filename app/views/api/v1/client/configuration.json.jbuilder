# frozen_string_literal: true

json.config do
  json.agent_update_interval @agent.advanced_configuration["agent_update_interval"]
  json.use_native_hashcat @agent.advanced_configuration["use_native_hashcat"]
  json.backend_device @agent.advanced_configuration["backend_device"]
end
json.api_version 1
