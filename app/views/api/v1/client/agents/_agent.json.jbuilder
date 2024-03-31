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
  json.use_native_hashcat agent.advanced_configuration[:use_native_hashcat]
  json.agent_update_interval agent.advanced_configuration[:agent_update_interval]
end
