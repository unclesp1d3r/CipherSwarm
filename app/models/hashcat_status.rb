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
#  id                                                       :bigint           not null, primary key, indexed => [task_id, created_at]
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
#  created_at                                               :datetime         not null, indexed => [task_id, id]
#  updated_at                                               :datetime         not null
#  task_id                                                  :bigint           not null, indexed => [created_at, id], indexed, indexed => [status, time]
#
# Indexes
#
#  index_hashcat_statuses_on_task_created_id_desc  (task_id,created_at DESC,id DESC)
#  index_hashcat_statuses_on_task_id               (task_id)
#  index_hashcat_statuses_on_task_status_time      (task_id,status,time DESC)
#  index_hashcat_statuses_on_time                  (time)
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
  # PERFORMANCE: Removed `touch: true` to eliminate cascading UPDATE storms.
  # HashcatStatus records are created every 5-30 seconds per active agent. With touch: true,
  # each creation triggered: Task.touch → Attack.touch (via Task belongs_to) → multiple
  # after_commit callbacks. This generated 6-10 extra UPDATEs per status submission.
  # Task/Attack freshness is tracked via explicit state machine transitions instead.
  belongs_to :task
  has_many :device_statuses, dependent: :destroy, autosave: true
  has_one :hashcat_guess, dependent: :destroy, autosave: true
  validates_associated :device_statuses
  validates_associated :hashcat_guess
  validates :time, presence: true
  validates :status, presence: true
  validates :session, presence: true, length: { maximum: 255 }
  validates :target, presence: true, length: { maximum: 255 }
  validates :time_start, presence: true
  validate :array_lengths_within_limits
  validate :device_statuses_count_within_limit

  accepts_nested_attributes_for :device_statuses, allow_destroy: true
  accepts_nested_attributes_for :hashcat_guess, allow_destroy: true

  after_create_commit :update_agent_metrics

  scope :latest, -> { order(time: :desc).first }
  scope :older_than, ->(time) { where(time: ...time) }

  # States for which status trimming applies. Includes all non-terminal states
  # (pending, running, paused, failed) since these tasks may still accumulate statuses.
  TRIMMABLE_STATES = %w[pending running paused failed].freeze

  # Trims statuses beyond the limit for non-terminal tasks using a single SQL subquery.
  # Uses ROW_NUMBER() window function to rank statuses per task and delete excess.
  # ON DELETE CASCADE on device_statuses and hashcat_guesses handles dependents.
  #
  # @param limit [Integer] maximum statuses to keep per task
  # @return [Integer] number of deleted rows
  def self.trim_excess_for_incomplete_tasks(limit:)
    return 0 unless limit.is_a?(Integer) && limit.positive?

    states = TRIMMABLE_STATES.map { |s| connection.quote(s) }.join(", ")
    connection.execute(sanitize_sql_array([<<~SQL.squish, limit])).cmd_tuples
      DELETE FROM hashcat_statuses
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY task_id
                   ORDER BY created_at DESC, id DESC
                 ) as rn
          FROM hashcat_statuses
          WHERE task_id IN (SELECT id FROM tasks WHERE state IN (#{states}))
        ) ranked
        WHERE rn > ?
      )
    SQL
  end

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
    hashes = recovered_hashes.presence || [0, 0]
    formatted_hashes_text = format("%d of %d", hashes[0].to_i, hashes[1].to_i)

    "#{formatted_progress_text} at #{formatted_speed_text} (#{formatted_hashes_text})"
  end

  # Generates a serializable hash representation of the object.
  #
  # @param options [Hash] Options for customizing the serialization.
  # @option options [Array<Symbol>] :include Additional associations to include in the serialization.
  #
  # @return [Hash] The serialized hash representation of the object.
  def serializable_hash(options = {})
    options = (options || {}).dup
    options[:include] = Array(options[:include]) + %i[device_statuses hashcat_guess]
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
    available_temps = device_statuses.map(&:temperature).compact.reject(&:negative?)
    current_temperature = available_temps.max || -1
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

    # Broadcast targeted updates since update_columns bypasses after_update_commit callbacks.
    # Replace just the hash rate value on index cards (subscribed to the bare agent stream)
    # and the overview tab on the show page (subscribed to [agent, :overview]).
    begin
      agent.broadcast_replace_later_to agent,
        target: ActionView::RecordIdentifier.dom_id(agent, :index_hash_rate),
        partial: "agents/index_hash_rate",
        locals: { agent: agent }
      agent.broadcast_replace_later_to [agent, :overview],
        target: ActionView::RecordIdentifier.dom_id(agent, :overview),
        partial: "agents/overview_tab",
        locals: { agent: agent }
    rescue StandardError => e
      Rails.logger.error(
        "[HashcatStatus] Failed to broadcast agent metrics for task #{task.id}: " \
        "#{e.class} - #{e.message}"
      )
    end
  rescue StandardError => e
    Rails.logger.error(
      "[HashcatStatus] Failed to update agent metrics for task #{task.id}: " \
      "#{e.class} - #{e.message}\n" \
      "Backtrace: #{e.backtrace&.first(5)&.join("\n           ")}"
    )
  end

  def array_lengths_within_limits
    errors.add(:progress, "must have exactly 2 entries") if progress.present? && progress.length != 2
    errors.add(:recovered_hashes, "must have exactly 2 entries") if recovered_hashes.present? && recovered_hashes.length != 2
    errors.add(:recovered_salts, "must have exactly 2 entries") if recovered_salts.present? && recovered_salts.length != 2
  end

  def device_statuses_count_within_limit
    errors.add(:device_statuses, "must have at most 64 entries") if device_statuses.present? && device_statuses.size > 64
  end
end
