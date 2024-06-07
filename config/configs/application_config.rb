# frozen_string_literal: true

# Base class for application config classes
class ApplicationConfig < Anyway::Config
  attr_config agent_considered_offline_time: 30.minutes,
              task_considered_abandoned_age: 30.minutes,
              max_benchmark_age: 1.week,
              max_offline_time: 12.hours

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
