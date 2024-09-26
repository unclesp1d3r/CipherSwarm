# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hashcat_benchmarks
#
#  id                                                                  :bigint           not null, primary key
#  benchmark_date(The date and time the benchmark was performed.)      :datetime         not null, indexed => [agent_id, hash_type]
#  device(The device used for the benchmark.)                          :integer          not null
#  hash_speed(The speed of the benchmark. In hashes per second.)       :float            not null
#  hash_type(The hashcat hash type.)                                   :integer          not null, indexed => [agent_id, benchmark_date]
#  runtime(The time taken to complete the benchmark. In milliseconds.) :bigint           not null
#  created_at                                                          :datetime         not null
#  updated_at                                                          :datetime         not null
#  agent_id                                                            :bigint           not null, indexed => [benchmark_date, hash_type]
#
# Indexes
#
#  idx_on_agent_id_benchmark_date_hash_type_a667ecb9be  (agent_id,benchmark_date,hash_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#
include ActiveSupport::NumberHelper

#
# The HashcatBenchmark model represents a benchmark result for a specific agent, device, and hash type.
# It includes validations, scopes, and methods to retrieve and manipulate benchmark data.
#
# This derives from the hashcat benchmark output and is used to track the performance of each agent.
#
# Associations:
# - belongs_to :agent, touch: true
#
# Validations:
# - benchmark_date: presence
# - device: presence, numericality (only_integer, greater_than_or_equal_to: 0)
# - hash_speed: presence, numericality (greater_than: 0)
# - hash_type: presence, numericality (only_integer, greater_than_or_equal_to: 0)
# - runtime: presence, numericality (only_integer, greater_than: 0)
# - agent: uniqueness (scope: %i[benchmark_date hash_type])
#
# Scopes:
# - by_hash_type(hash_type)
# - by_device(device)
# - by_agent(agent)
# - by_agent_and_date(agent, date)
# - by_agent_hash_type_and_date(agent, hash_type, date)
# - by_agent_device_and_date(agent, device, date)
# - by_agent_hash_type_device_and_date(agent, hash_type, device, date)
# - by_agent_and_hash_type(agent, hash_type)
# - by_agent_and_device(agent, device)
#
# Class Methods:
# - fastest_agent_for_hash_type(hash_type): Finds the agent with the highest total hash speed for a given hash type.
# - fastest_by_agent: Returns the fastest benchmark for each agent.
# - fastest_by_hash_type: Returns the fastest benchmark for each hash type.
# - fastest_device_for_hash_type(hash_type): Returns the fastest device for a given hash type.
# - sum_hash_speed_for_agent(agent, hash_type): Sums the hash speed for a given agent and hash type.
#
# Instance Methods:
# - to_s: Returns a string representation of the benchmark.
class HashcatBenchmark < ApplicationRecord
  belongs_to :agent, touch: true

  # Validations
  validates :benchmark_date, presence: true
  validates :device, presence: true
  validates :hash_speed, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :hash_type, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :runtime, presence: true, numericality: { only_integer: true }
  validates :agent, uniqueness: { scope: %i[benchmark_date hash_type] }
  validates :hash_speed, numericality: { greater_than: 0 }
  validates :runtime, numericality: { greater_than: 0 }
  validates :device, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :hash_type, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  broadcasts_refreshes unless Rails.env.test?

  # Scopes
  scope :by_hash_type, ->(hash_type) { where(hash_type: hash_type) }
  scope :by_device, ->(device) { where(device: device) }
  scope :by_agent, ->(agent) { where(agent: agent) }
  scope :by_agent_and_date, ->(agent, date) { where(agent: agent, benchmark_date: date) }
  scope :by_agent_hash_type_and_date, ->(agent, hash_type, date) { where(agent: agent, hash_type: hash_type, benchmark_date: date) }
  scope :by_agent_device_and_date, ->(agent, device, date) { where(agent: agent, device: device, benchmark_date: date) }
  scope :by_agent_hash_type_device_and_date, ->(agent, hash_type, device, date) { where(agent: agent, hash_type: hash_type, device: device, benchmark_date: date) }
  scope :by_agent_and_hash_type, ->(agent, hash_type) { where(agent: agent, hash_type: hash_type) }
  scope :by_agent_and_device, ->(agent, device) { where(agent: agent, device: device) }

  # Finds the agent with the highest total hash speed for a given hash type.
  #
  # @param [Integer] hash_type The hashcat hash type.
  # @return [Integer, nil] The ID of the agent with the highest total hash speed, or nil if no benchmarks are found.
  def self.fastest_agent_for_hash_type(hash_type)
    # Using the sum of hash speeds for all devices in an agent, find the agent with the highest total hash_speed for a hash_type
    by_hash_type(hash_type).group(:agent_id).sum(:hash_speed).max_by { |_k, v| v }&.first
  end

  # Returns the fastest benchmark for each agent.
  #
  # @return [Hash{Agent => HashcatBenchmark}] a hash mapping agents to their fastest benchmarks
  def self.fastest_by_agent
    Agent.all.map do |agent|
      benchmark = by_agent(agent).order(hash_speed: :desc).first
      [agent, benchmark]
    end.to_h
  end

  # Returns the fastest benchmark for each hash type.
  #
  # @return [Hash{HashType => HashcatBenchmark}] a hash mapping hash types to their fastest benchmarks
  def self.fastest_by_hash_type
    HashType.all.map do |hash_type|
      benchmark = by_hash_type(hash_type.hashcat_mode).order(hash_speed: :desc).first
      [hash_type, benchmark]
    end.to_h
  end

  # Returns the device with the fastest hash speed for a given hash type.
  #
  # @param hash_type [String] the type of hash to filter devices by.
  # @return [HashcatBenchmark, nil] the device with the highest hash speed for the specified hash type, or nil if no devices are found.
  def self.fastest_device_for_hash_type(hash_type)
    by_hash_type(hash_type).order(hash_speed: :desc).first
  end

  # Sums the hash speeds for a given agent and hash type.
  #
  # @param agent [Agent] the agent for which to sum the hash speeds
  # @param hash_type [String] the type of hash for which to sum the speeds
  # @return [Numeric] the total hash speed for the specified agent and hash type
  def self.sum_hash_speed_for_agent(agent, hash_type)
    by_agent_and_hash_type(agent, hash_type).sum(:hash_speed)
  end

  # Returns a string representation of the hashcat benchmark.
  # If the hash type record is found, it includes the hash type name and the human-readable hash speed.
  # Otherwise, it includes the hash type and the raw hash speed.
  #
  # @return [String] the string representation of the hashcat benchmark
  def to_s
    # The hash type record is found by the hashcat mode number
    # These record virtually never change, so we can cache them very safely
    hash_type_record = Rails.cache.fetch("hash_type/#{hash_type}", expires: 1.day) do
      HashType.find_by(hashcat_mode: hash_type)&.name
    end
    if hash_type_record.nil?
      "#{hash_type} #{hash_speed} h/s"
    else
      "#{hash_type} (#{hash_type_record}) - #{number_to_human(hash_speed, prefix: :si)} hashes/sec"
    end
  end
end
