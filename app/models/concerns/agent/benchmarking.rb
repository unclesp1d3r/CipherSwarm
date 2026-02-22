# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Agent::Benchmarking provides benchmark-related functionality for Agent models.
#
# This concern encapsulates methods for managing and querying hashcat benchmark data,
# including performance threshold checks, benchmark aggregation, and staleness detection.
#
# REASONING:
# - Extracted benchmark logic from Agent model to improve code organization and reduce model complexity.
# - Benchmarking is a cohesive set of functionality that operates on hashcat_benchmarks association.
# Alternatives Considered:
# - Keep methods in Agent model: Would significantly increase model size and mix concerns.
# - Use a service object: Overkill for query/formatting methods that don't involve complex business logic.
# - Use a PORO decorator: Adds complexity without benefit since methods are tightly coupled to Agent.
# Decision:
# - ActiveSupport::Concern provides clean extraction with access to Agent associations and validations.
# Performance Implications:
# - Caching hash_type lookups with 1-week expiry reduces database queries.
# - Uses efficient ActiveRecord queries (group, sum, pluck) rather than Ruby iteration.
# Future Considerations:
# - Could add benchmark comparison methods between agents.
# - Consider moving to background job if aggregation becomes slow for agents with many benchmarks.
#
# @example Basic usage
#   agent.needs_benchmark?
#   # => true if benchmarks are older than max_benchmark_age
#
#   agent.meets_performance_threshold?(0) # hashcat mode 0 = MD5
#   # => true if agent's hash speed meets minimum threshold
#
#   agent.aggregate_benchmarks
#   # => ["0 (MD5) - 1.23 Gh hashes/sec", "100 (SHA1) - 500 Mh hashes/sec"]
#
module Agent::Benchmarking
  extend ActiveSupport::Concern

  included do
    include ActionView::Helpers::NumberHelper
  end

  # Aggregates benchmark data for the agent.
  #
  # This method processes the most recent benchmark records associated with the agent.
  # It combines the hash speeds of benchmarks grouped by hash type and formats
  # the summarized results into descriptive strings.
  # If there are no recent benchmarks, or grouped summaries are not available, it returns nil.
  #
  # @return [Array<String>, nil] A collection of formatted benchmark summaries.
  #   Each summary describes the hash type and its aggregated speed.
  #   Returns nil if there are no benchmarks to process.
  def aggregate_benchmarks
    return nil if last_benchmarks.blank?

    benchmark_summaries = last_benchmarks&.group(:hash_type)&.sum(:hash_speed)
    return nil if benchmark_summaries.blank?

    benchmark_summaries.map { |hash_type, speed| format_benchmark_summary(hash_type, speed) }
  end

  # Retrieves the allowed hash types for the agent.
  #
  # This method queries the associated `hashcat_benchmarks` for unique hash types.
  # It returns a list of distinct hash types supported by the agent, based on its stored benchmark data.
  #
  # @return [Array<Integer>] An array containing distinct hashcat mode identifiers supported by the agent.
  def allowed_hash_types
    hashcat_benchmarks.distinct.pluck(:hash_type)
  end

  # Detects whether the agent is currently running benchmarks.
  #
  # An agent is considered to be benchmarking when it is in the pending state,
  # has recently checked in (within the last minute), and has no benchmark
  # results on record. This is used to show a "Benchmarking..." indicator
  # on the Overview tab instead of a generic "Pending" state.
  #
  # @return [Boolean] true if the agent appears to be actively benchmarking
  def benchmarking?
    pending? && last_seen_at.present? && last_seen_at > 1.minute.ago && !hashcat_benchmarks.exists?
  end

  # Returns the last benchmarks recorded for the agent as an array of strings.
  #
  # If there are no benchmarks available, it returns nil.
  #
  # @return [Array<String>, nil] The last benchmarks recorded for the agent, or nil if there are no benchmarks.
  def benchmarks
    return nil if last_benchmarks.blank?

    last_benchmarks.map(&:to_s)
  end

  # Formats a benchmark summary string based on the hash type and speed.
  #
  # @param hash_type [Integer] The hashcat mode identifier for the hash type.
  # @param speed [Float] The speed of the hashing process in hashes per second.
  # @return [String] A formatted string summarizing the benchmark. If the hash type
  #   is found in the HashType model, it includes the hash type name and a human-readable
  #   speed. Otherwise, it returns a string with the hash type and speed in h/s.
  def format_benchmark_summary(hash_type, speed)
    hash_type_record = Rails.cache.fetch("#{cache_key_with_version}/hash_type/#{hash_type}/name", expires_in: 1.week) do
      HashType.find_by(hashcat_mode: hash_type)
    end

    if hash_type_record.nil?
      "#{hash_type} #{speed} h/s"
    else
      "#{hash_type} (#{hash_type_record.name}) - #{number_to_human(speed, prefix: :si)} hashes/sec"
    end
  end

  # Returns the date of the last benchmark.
  #
  # If there are no benchmarks, it returns the date from a year ago.
  #
  # @return [Date, ActiveSupport::TimeWithZone] The date of the last benchmark.
  def last_benchmark_date
    if hashcat_benchmarks.empty?
      # If there are no benchmarks, we'll just return the date from a year ago.
      # Guard against nil created_at for unsaved agents.
      base_time = created_at || Time.zone.now
      base_time - 365.days
    else
      hashcat_benchmarks.order(benchmark_date: :desc).first.benchmark_date
    end
  end

  # Returns the last benchmarks recorded for the agent.
  #
  # If there are no benchmarks available, it returns nil.
  #
  # @return [ActiveRecord::Relation, nil] The last benchmarks recorded for the agent,
  #   or nil if there are no benchmarks.
  def last_benchmarks
    return nil if hashcat_benchmarks.empty?

    max = hashcat_benchmarks.maximum(:benchmark_date)
    hashcat_benchmarks.where(benchmark_date: max.all_day).order(hash_type: :asc)
  end

  # Checks if the agent meets the minimum performance benchmark for a specific hash type.
  #
  # This method calculates the total hash speed for the agent for the given hash type
  # and compares it to the minimum performance benchmark defined in the application configuration.
  #
  # @param hash_type [Integer] The hashcat mode identifier to check the performance benchmark for.
  # @return [Boolean] true if the agent meets or exceeds the minimum performance benchmark, false otherwise.
  def meets_performance_threshold?(hash_type)
    total_hash_speed = hashcat_benchmarks.where(hash_type: hash_type).sum(:hash_speed)
    total_hash_speed >= ApplicationConfig.min_performance_benchmark
  end

  # Determines if the agent needs a benchmark based on the last benchmark date
  # and the maximum allowed benchmark age defined in the application configuration.
  #
  # @return [Boolean] true if the agent needs a benchmark, false otherwise
  def needs_benchmark?
    # A benchmark is needed if the last_benchmark_date is older than the max_benchmark_age.
    last_benchmark_date <= ApplicationConfig.max_benchmark_age.ago
  end
end
