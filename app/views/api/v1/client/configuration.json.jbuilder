# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.config do
  json.partial! "api/v1/client/agents/advanced_configuration", agent: @agent
end
json.api_version 1
json.benchmarks_needed @agent.needs_benchmark?

json.recommended_timeouts do
  json.connect_timeout ApplicationConfig.recommended_connect_timeout
  json.read_timeout ApplicationConfig.recommended_read_timeout
  json.write_timeout ApplicationConfig.recommended_write_timeout
  json.request_timeout ApplicationConfig.recommended_request_timeout
end

json.recommended_retry do
  json.max_attempts ApplicationConfig.recommended_retry_max_attempts
  json.initial_delay ApplicationConfig.recommended_retry_initial_delay
  json.max_delay ApplicationConfig.recommended_retry_max_delay
end

json.recommended_circuit_breaker do
  json.failure_threshold ApplicationConfig.recommended_circuit_breaker_failure_threshold
  json.timeout ApplicationConfig.recommended_circuit_breaker_timeout
end
