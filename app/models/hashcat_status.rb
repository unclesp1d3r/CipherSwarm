require "date"
# == Schema Information
#
# Table name: hashcat_statuses
#
#  id                                                       :bigint           not null, primary key
#  estimated_stop(The estimated time of completion)         :datetime
#  original_line(The original line from the hashcat output) :text
#  progress(The progress in percentage)                     :integer          is an Array
#  recovered_hashes(The number of recovered hashes)         :integer          is an Array
#  recovered_salts(The number of recovered salts)           :integer          is an Array
#  rejected(The number of rejected hashes)                  :integer
#  restore_point(The restore point)                         :integer
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

  enum status: { running: 3, exhausted: 5, cracked: 6, aborted: 7, quit: 8 }

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

  def status_text
    status.to_s.capitalize
  end

  def estimated_time
    estimated_stop - Time.zone.now
  end
end