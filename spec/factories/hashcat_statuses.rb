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
FactoryBot.define do
  factory :hashcat_status do
    task
    time { "2024-03-30 19:30:19" }
    original_line { "MyText" }
    session { "MyString" }
    status { :running }
    target { "MyString" }
    progress { [ 1 ] }
    restore_point { 1 }
    recovered_hashes { [ 1 ] }
    recovered_salts { [ 1 ] }
    rejected { 1 }
    time_start { "2024-03-30 19:30:19" }
    estimated_stop { "2024-03-30 19:30:19" }
  end
end
