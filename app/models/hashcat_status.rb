# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Tracks and manages hashcat process status and associated device information.
#
# @relationships
# - belongs_to :task (touch: true)
# - has_many :device_statuses (dependent: destroy, autosave)
# - has_one :hashcat_guess (dependent: destroy, autosave)
#
# @validations
# - time, status, session, target, time_start: present
# - session, target: max 255 chars
# - device_statuses, hashcat_guess: valid associations
#
# @scopes
# - latest: most recent by time
# - older_than(time): before specified time
#
# @delegates
# - guess_base_count, guess_base_offset to hashcat_guess
#
# == Schema Information
#
# Table name: hashcat_statuses
#
#  id                                                       :bigint           not null, primary key
#  estimated_stop(The estimated time of completion)         :datetime
#  original_line(The original line from the hashcat output) :text
#  progress(The progress in percentage)                     :bigint           is an Array
#  recovered_hashes(The number of recovered hashes)         :bigint           is an Array
#  recovered_salts(The number of recovered salts)           :bigint           is an Array
#  rejected(The number of rejected hashes)                  :bigint
#  restore_point(The restore point)                         :bigint
#  session(The session name)                                :string           not null
#  status(The status code)                                  :integer          not null, indexed => [task_id, time]
#  target(The target file)                                  :string           not null
#  time(The time of the status)                             :datetime         not null, indexed => [task_id, status], indexed
#  time_start(The time the task started)                    :datetime         not null
#  created_at                                               :datetime         not null
#  updated_at                                               :datetime         not null
#  task_id                                                  :bigint           not null, indexed, indexed => [status, time]
#
# Indexes
#
#  index_hashcat_statuses_on_task_id           (task_id)
#  index_hashcat_statuses_on_task_status_time  (task_id,status,time DESC)
#  index_hashcat_statuses_on_time              (time)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id) ON DELETE => cascade
#
require "date"

# This class represents the status of a Hashcat task and its associated
# properties, such as the current progress, status, device speeds, and
# other key metrics. It tracks the progress of hash cracking tasks, stores
# information about related devices, and provides utility methods to calculate
# metrics and format data for display or serialization.
class HashcatStatus < ApplicationRecord
  include ActiveSupport::NumberHelper
  belongs_to :task, touch: true
  has_many :device_statuses, dependent: :destroy, autosave: true
  has_one :hashcat_guess, dependent: :destroy, autosave: true
  validates_associated :device_statuses
  validates_associated :hashcat_guess
  validates :time, presence: true
  validates :status, presence: true
  validates :session, presence: true, length: { maximum: 255 }
  validates :target, presence: true, length: { maximum: 255 }
  validates :time_start, presence: true

  accepts_nested_attributes_for :device_statuses, allow_destroy: true
  accepts_nested_attributes_for :hashcat_guess, allow_destroy: true

  after_create_commit :update_agent_metrics

  scope :latest, -> { order(time: :desc).first }
  scope :older_than, ->(time) { where(time: ...time) }

  delegate :guess_base_count, to: :hashcat_guess
  delegate :guess_base_offset, to: :hashcat_guess

  enum :status, {
    initializing: 0, # Hashcat is initializing, which is the process of setting up the environment.
    autotuning: 1, # Hashcat is autotuning, which is a process to determine the optimal settings for the current hardware.
    self_testing: 2, # Hashcat is self-testing, which is a process to ensure that the hardware is functioning correctly.
    running: 3, # Hashcat is running, which is the process of cracking the hashes.
    paused: 4, # Hashcat is paused, which means that the process has been temporarily stopped.
    exhausted: 5, # Hashcat is exhausted, which means that the process has run out of guesses.
    cracked: 6, # Hashcat has cracked the hashes.
    aborted: 7, # Hashcat has aborted the process.
    quit: 8, # Hashcat has quit the process.
    bypassed: 9, # Hashcat has bypassed the process, which means that the process has been skipped.
    aborted_session_checkpoint: 10, # Hashcat has aborted the process at a session checkpoint.
    aborted_runtime_limit: 11, # Hashcat has aborted the process due to a runtime limit.
    error: 13, # Hashcat has encountered an error.
    aborted_finish: 14, # Hashcat has aborted the process at the finish, which means that the process has been stopped.
    autodetecting: 16 # Hashcat is autodetecting, which is the process of automatically detecting the hash type.
  }

  # Returns the current iteration of the Hashcat task.
  # The iteration is based on the guess base offset.
  #
  # @return [Integer] the current iteration, or 0 if no offset is present
  def current_iteration
    (guess_base_offset.presence || 0)
  end

  # Calculates the total speed of all devices.
  # If there are no device statuses, it returns 0.
  #
  # @return [Integer] the total speed of all devices
  def device_speed
    device_statuses.blank? ? 0 : device_statuses.sum(&:speed)
  end

  # Returns the estimated time remaining for the process to complete.
  # The time is calculated based on the estimated stop time and is
  # presented in a human-readable format (e.g., "about 5 minutes").
  #
  # @return [String] the estimated time remaining in words
  def estimated_time
    time_ago_in_words(estimated_stop)
  end

  # Calculates the progress percentage of the Hashcat task.
  # The progress is calculated based on the progress array, which contains
  # the current progress and the total progress.
  #
  # @return [Float, Integer] the progress percentage rounded to two decimal places
  def progress_percentage
    return 0.0 unless progress.present? && progress.is_a?(Array) && progress[1].positive? && progress[0].positive?

    progress_value = (progress[0].to_f / progress[1].to_f) * 100
    progress_value.round(2)
  end

  # Returns a formatted string representing the progress of the Hashcat task.
  # The string includes the progress percentage, iteration information, device speed, and recovered hashes.
  #
  # @return [String] the formatted progress text
  def progress_text
    progress_percentage_text = number_to_percentage(progress_percentage, precision: 2)
    is_multiple_iterations = guess_base_count.present? && guess_base_offset.present? && guess_base_count > 1

    formatted_progress_text = is_multiple_iterations ?
      format("%s for iteration %d of %d", progress_percentage_text, current_iteration, guess_base_count) : progress_percentage_text

    formatted_speed_text = number_to_human(device_speed, units: { unit: "H/s", thousand: "KH/s", million: "MH/s", billion: "GH/s" })
    formatted_hashes_text = format("%d of %d", recovered_hashes[0], recovered_hashes[1])

    "#{formatted_progress_text} at #{formatted_speed_text} (#{formatted_hashes_text})"
  end

  # Generates a serializable hash representation of the object.
  #
  # @param options [Hash] Options for customizing the serialization.
  # @option options [Array<Symbol>] :include Additional associations to include in the serialization.
  #
  # @return [Hash] The serialized hash representation of the object.
  def serializable_hash(options = {})
    options ||= {}
    if options[:include]
      options[:include].concat %i[device_statuses hashcat_guess]
    else
      options[:include] = %i[device_statuses hashcat_guess]
    end
    super(options)
  end

  # Returns the status as a capitalized string.
  #
  # @return [String] the capitalized status text
  def status_text
    status.to_s.capitalize
  end

  # Returns the total number of iterations for the Hashcat task.
  # The total iterations are based on the guess base count.
  #
  # @return [Integer] the total number of iterations, or 0 if no count is present
  def total_iterations
    guess_base_count.presence || 0
  end

  private

  # Updates the agent's cached metrics from this status update.
  #
  # Only updates metrics if the status is :running. Throttles updates to prevent
  # excessive database writes by checking if metrics were updated less than 30 seconds ago.
  #
  # Calculates aggregated metrics from all device statuses:
  # - current_hash_rate: sum of all device speeds
  # - current_temperature: maximum temperature across devices
  # - current_utilization: average utilization across devices
  #
  # Uses update_columns to bypass callbacks and avoid touching timestamps.
  #
  # @return [void]
  def update_agent_metrics
    return unless running? # Only update metrics for running status

    agent = task.agent
    return if agent.blank?

    # Throttle updates: skip if metrics were updated less than 30 seconds ago
    if agent.metrics_updated_at.present? && agent.metrics_updated_at > 30.seconds.ago
      return
    end

    # Calculate aggregate metrics from device statuses
    current_hash_rate = device_statuses.sum(&:speed)
    current_temperature = device_statuses.map(&:temperature).compact.max || 0
    current_utilization = if device_statuses.any?
                           (device_statuses.sum(&:utilization).to_f / device_statuses.count).round
    else
                           0
    end

    # Update agent metrics using direct SQL to avoid callbacks and timestamp touching
    # rubocop:disable Rails/SkipsModelValidations
    agent.update_columns(
      current_hash_rate: current_hash_rate,
      current_temperature: current_temperature,
      current_utilization: current_utilization,
      metrics_updated_at: Time.zone.now
    )
    # rubocop:enable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error("Failed to update agent metrics for task #{task.id}: #{e.message}")
  end
end
