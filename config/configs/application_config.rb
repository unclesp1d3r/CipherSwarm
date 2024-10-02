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
              min_performance_benchmark: 1000

  class << self
    # Make it possible to access a singleton config instance
    # via class methods (i.e., without explicitly calling `instance`)
    delegate_missing_to :instance

    private

    # Returns a singleton config instance
    def instance
      @instance ||= new
    end
  end
end
