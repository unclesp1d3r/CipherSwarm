# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.config do
  json.partial! "api/v1/client/agents/advanced_configuration", agent: @agent
end
json.api_version 1
