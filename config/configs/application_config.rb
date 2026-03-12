# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Base class for application config classes

# ApplicationConfig is a configuration class that inherits from Anyway::Config.
# It provides a set of configurable attributes with default values and allows
# access to a singleton instance of the configuration via class methods.
#
# Attributes:
# - agent_considered_offline_time: Time duration (default: 30 minutes)
# - task_considered_abandoned_age: Time duration (default: 30 minutes)
# - max_benchmark_age: Time duration (default: 1 week)
# - max_offline_time: Time duration (default: 12 hours)
# - task_status_limit: Integer (default: 10)
# - min_performance_benchmark: Integer (default: 1000)
# - hash_list_batch_size: Integer (default: 1000)
# - agent_error_retention: Time duration for retaining agent errors (default: 30 days)
# - audit_retention: Time duration for retaining audit records (default: 90 days)
# - hashcat_status_retention: Time duration for retaining completed task status (default: 7 days)
# - recommended_connect_timeout: Integer, seconds for TCP connect timeout (default: 10)
# - recommended_read_timeout: Integer, seconds for read timeout (default: 30)
# - recommended_write_timeout: Integer, seconds for write timeout (default: 30)
# - recommended_request_timeout: Integer, seconds for overall request timeout (default: 60)
# - recommended_retry_max_attempts: Integer, max retry attempts (default: 10)
# - recommended_retry_initial_delay: Integer, seconds for initial retry delay (default: 1)
# - recommended_retry_max_delay: Integer, seconds for max retry delay (default: 300)
# - recommended_circuit_breaker_failure_threshold: Integer, failures before circuit opens (default: 5)
# - recommended_circuit_breaker_timeout: Integer, seconds before circuit half-opens (default: 30)
#
# Class Methods:
# - instance: Returns a singleton instance of the configuration.
#
# The class uses `delegate_missing_to` to delegate any missing methods to the
# singleton instance, allowing for easy access to configuration attributes
# without explicitly calling `instance`.
class ApplicationConfig < Anyway::Config
  attr_config agent_considered_offline_time: 30.minutes,
              task_considered_abandoned_age: 30.minutes,
              max_benchmark_age: 1.week,
              max_offline_time: 12.hours,
              task_status_limit: 10,
              min_performance_benchmark: 1000,
              hash_list_batch_size: 1000,
              agent_error_retention: 30.days,
              audit_retention: 90.days,
              hashcat_status_retention: 7.days,
              recommended_connect_timeout: 10,
              recommended_read_timeout: 30,
              recommended_write_timeout: 30,
              recommended_request_timeout: 60,
              recommended_retry_max_attempts: 10,
              recommended_retry_initial_delay: 1,
              recommended_retry_max_delay: 300,
              recommended_circuit_breaker_failure_threshold: 5,
              recommended_circuit_breaker_timeout: 30

  class << self
    # Make it possible to access a singleton config instance
    # via class methods (i.e., without explicitly calling `instance`)
    delegate_missing_to :instance

    private

    # Returns a singleton config instance using thread-safe initialization
    # Using class instance variable for singleton pattern - acceptable in this context
    # rubocop:disable ThreadSafety/ClassInstanceVariable
    def instance
      return @instance if defined?(@instance)

      @mutex ||= Mutex.new
      @mutex.synchronize do
        @instance ||= new
      end
    end
    # rubocop:enable ThreadSafety/ClassInstanceVariable
  end
end
