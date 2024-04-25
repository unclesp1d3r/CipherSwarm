# frozen_string_literal: true

json.config do
  json.partial! "api/v1/client/agents/advanced_configuration", agent: @agent
end
json.api_version 1
