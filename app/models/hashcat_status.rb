# frozen_string_literal: true

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
#  status(The status code)                                  :integer          not null
#  target(The target file)                                  :string           not null
#  time(The time of the status)                             :datetime         not null
#  time_start(The time the task started)                    :datetime         not null
#  created_at                                               :datetime         not null
#  updated_at                                               :datetime         not null
#  task_id                                                  :bigint           not null, indexed
#
# Indexes
#
#  index_hashcat_statuses_on_task_id  (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id) ON DELETE => cascade
#
require "date"

# The HashcatStatus model represents the status of a Hashcat task.
#
# It derives from the Hashcat status output and is used to track the progress of the cracking process.
#
# Associations:
# - belongs_to :task
# - has_many :device_statuses
# - has_one :hashcat_guess
#
# Validations:
# - validates_associated :device_statuses
# - validates_associated :hashcat_guess
# - validates :time, presence: true
# - validates :status, presence: true
# - validates :session, presence: true, length: { maximum: 255 }
# - validates :target, presence: true, length: { maximum: 255 }
# - validates :time_start, presence: true
#
# Nested Attributes:
# - accepts_nested_attributes_for :device_statuses, allow_destroy: true
# - accepts_nested_attributes_for :hashcat_guess, allow_destroy: true
#
# Scopes:
# - latest: Returns the latest HashcatStatus based on time.
# - older_than(time): Returns HashcatStatus records older than the given time.
#
# Delegations:
# - guess_base_count: Delegates to :hashcat_guess
# - guess_base_offset: Delegates to :hashcat_guess
#
# Enums:
# - status: Defines various status values for the Hashcat task.
#
# Instance Methods:
# - estimated_time: Returns the estimated time until the process stops in words.
# - serializable_hash(options = {}): Customizes the serialization to include associated records.
# - status_text: Returns the capitalized string representation of the status.
class HashcatStatus < ApplicationRecord
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

  # Returns the estimated time remaining for the process to complete.
  # The time is calculated based on the estimated stop time and is
  # presented in a human-readable format (e.g., "about 5 minutes").
  #
  # @return [String] the estimated time remaining in words
  def estimated_time
    time_ago_in_words(estimated_stop)
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
end
