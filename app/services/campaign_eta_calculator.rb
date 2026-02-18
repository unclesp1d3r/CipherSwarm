# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# CampaignEtaCalculator computes estimated completion times for campaigns.
#
# This service encapsulates ETA calculation logic, which considers:
# - Running attacks and their task progress
# - Pending/paused attacks and their estimated durations
# - Hash rate benchmarks for complexity-based estimations
#
# Results are cached to avoid expensive recalculations on every request.
#
# @example Basic usage
#   calculator = CampaignEtaCalculator.new(campaign)
#   calculator.current_eta  # ETA for currently running work
#   calculator.total_eta    # ETA including pending attacks
#
# @example Without caching (for testing or forced recalculation)
#   calculator = CampaignEtaCalculator.new(campaign, cache: false)
#   calculator.current_eta
#
class CampaignEtaCalculator
  # @return [Campaign] the campaign to calculate ETAs for
  attr_reader :campaign

  # @return [Boolean] whether to use caching for calculations
  attr_reader :cache_enabled

  # Initializes a new CampaignEtaCalculator.
  #
  # @param campaign [Campaign] the campaign to calculate ETAs for
  # @param cache [Boolean] whether to cache results (default: true)
  def initialize(campaign, cache: true)
    @campaign = campaign
    @cache_enabled = cache
  end

  # Returns the cached current ETA for running attacks.
  #
  # @return [Time, nil] the estimated completion time, or nil if no work running
  def current_eta
    with_cache("current_eta") { calculate_current_eta }
  end

  # Returns the cached total ETA including pending attacks.
  #
  # @return [Time, nil] the estimated total completion time, or nil if no work
  def total_eta
    with_cache("total_eta") { calculate_total_eta }
  end

  private

  # Calculates the current ETA based on running attacks and tasks.
  #
  # @return [Time, nil] the maximum estimated finish time from running tasks
  def calculate_current_eta
    running_attacks = campaign.attacks.with_state(:running)
    return nil if running_attacks.blank?

    running_tasks = Task.joins(:attack)
                        .where(attacks: { id: running_attacks.ids })
                        .with_state(:running)

    running_tasks.filter_map(&:estimated_finish_time).max
  end

  # Calculates the total ETA including running, pending, and paused attacks.
  #
  # When only running attacks are present, returns the current running ETA so the
  # campaign summary shows a concrete value instead of nil/"Calculating…".
  #
  # @return [Time, nil] the total estimated completion time
  def calculate_total_eta
    unfinished_attacks = campaign.attacks.without_states(:completed, :exhausted)
    return nil if unfinished_attacks.blank?

    current_eta_time = calculate_current_eta
    pending_attacks = unfinished_attacks.with_states(:pending, :paused)

    return current_eta_time if pending_attacks.blank?

    additional_seconds = estimate_pending_duration(pending_attacks)

    build_total_eta(current_eta_time, additional_seconds)
  end

  # Estimates the total duration for pending attacks based on complexity.
  #
  # @param attacks [ActiveRecord::Relation<Attack>] pending attacks
  # @return [Float] estimated seconds to complete all attacks
  def estimate_pending_duration(attacks)
    total_seconds = 0.0

    attacks.find_each do |attack|
      total_seconds += estimate_attack_duration(attack)
    end

    total_seconds
  end

  # Estimates duration for a single attack based on complexity and hash rate.
  #
  # @param attack [Attack] the attack to estimate
  # @return [Float] estimated seconds, or 0 if estimation not possible
  def estimate_attack_duration(attack)
    complexity = attack.complexity_value.to_f
    return 0.0 if complexity.zero?

    hash_rate = fastest_hash_rate(attack.hash_mode)
    return 0.0 if hash_rate.nil? || hash_rate.zero?

    complexity / hash_rate
  end

  # Finds the fastest benchmark hash rate for a hash mode.
  #
  # @param hash_mode [Integer, String] the hashcat mode
  # @return [Numeric, nil] the hash rate in H/s, or nil if no benchmark
  def fastest_hash_rate(hash_mode)
    return nil if hash_mode.blank?

    HashcatBenchmark.fastest_device_for_hash_type(hash_mode)&.hash_speed
  end

  # Builds the total ETA from current ETA and additional seconds.
  #
  # @param current_eta_time [Time, nil] the current ETA baseline
  # @param additional_seconds [Float] seconds to add
  # @return [Time, nil] the calculated total ETA
  def build_total_eta(current_eta_time, additional_seconds)
    if current_eta_time.present?
      current_eta_time + additional_seconds.seconds
    elsif additional_seconds.positive?
      Time.current + additional_seconds.seconds
    end
  end

  # Wraps calculation in cache if caching is enabled.
  #
  # @param suffix [String] the cache key suffix
  # @yield the calculation to perform
  # @return the cached or calculated result
  def with_cache(suffix)
    return yield unless cache_enabled

    Rails.cache.fetch(cache_key(suffix)) { yield }
  end

  # Generates a cache key for the campaign that incorporates attack and task freshness.
  #
  # The key includes the latest updated_at timestamps from attacks and tasks so that
  # the cache is automatically busted when work progresses (e.g., status updates,
  # state transitions, or task completions).
  #
  # @param suffix [String] the cache key suffix
  # @return [String] the full cache key
  def cache_key(suffix)
    attacks_freshness = campaign.attacks.maximum(:updated_at).to_i
    tasks_freshness = Task.where(attack_id: campaign.attack_ids).maximum(:updated_at).to_i
    "#{campaign.cache_key_with_version}/eta/#{suffix}/#{attacks_freshness}-#{tasks_freshness}"
  end
end
