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
#  session(The session name)                                :string
#  status(The status code)                                  :integer
#  target(The target file)                                  :string
#  time(The time of the status)                             :datetime
#  time_start(The time the task started)                    :datetime
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
#  fk_rails_...  (task_id => tasks.id)
#
require "date"

class HashcatStatus < ApplicationRecord
  belongs_to :task, touch: true
  has_many :device_statuses, dependent: :destroy
  has_one :hashcat_guess, dependent: :destroy
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

  enum status: {
    initializing: 0,
    autotuning: 1,
    self_testing: 2,
    running: 3,
    paused: 4,
    exhausted: 5,
    cracked: 6,
    aborted: 7,
    quit: 8,
    bypassed: 9,
    aborted_session_checkpoint: 10,
    aborted_runtime_limit: 11,
    error: 13,
    aborted_finish: 14,
    autodetecting: 16
  }

  # Returns the estimated time until the process stops.
  #
  # @return [String] The estimated time in words.
  def estimated_time
    time_ago_in_words(estimated_stop)
  end

  def serializable_hash(options = {})
    options ||= {}
    if options[:include]
      options[:include].concat %i[device_statuses hashcat_guess]
    else
      options[:include] = %i[device_statuses hashcat_guess]
    end
    super(options)
  end

  # Returns the capitalized string representation of the status.
  #
  # @return [String] The capitalized status text.
  def status_text
    status.to_s.capitalize
  end
end
