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
  has_many :hashcat_guesses, dependent: :destroy
  validates :time, presence: true
  validates :status, presence: true
  validates :session, presence: true, length: { maximum: 255 }
  validates :target, presence: true, length: { maximum: 255 }
  validates :time_start, presence: true

  accepts_nested_attributes_for :device_statuses, allow_destroy: true
  accepts_nested_attributes_for :hashcat_guesses, allow_destroy: true

  scope :latest, -> { order(time: :desc).first }
  scope :older_than, ->(time) { where("time < ?", time) }

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

  def estimated_stop=(time_stop)
    case time_stop
    when Integer
      super(Time.zone.at(time_stop).to_datetime)
    when String
      super(Time.zone.at(time_stop.to_i).to_datetime)
    else
      super
    end
  end

  # Returns the estimated time until the process stops.
  #
  # @return [String] The estimated time in words.
  def estimated_time
    time_ago_in_words(estimated_stop)
  end

  # Returns the capitalized string representation of the status.
  #
  # @return [String] The capitalized status text.
  def status_text
    status.to_s.capitalize
  end

  def time_start=(time_start)
    case time_start
    when Integer
      super(Time.zone.at(time_start).to_datetime)
    when String
      super(Time.zone.at(time_start.to_i).to_datetime)
    else
      super
    end
  end
end
