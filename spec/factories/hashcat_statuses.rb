# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
FactoryBot.define do
  factory :hashcat_status do
    task
    time { Faker::Time.between(from: DateTime.now - 1, to: DateTime.now) }
    original_line { "MyText" }
    session { "MyString" }
    status { :running }
    target { "MyString" }
    progress { [1, 10000] }
    restore_point { 1 }
    recovered_hashes { [1, 2] }
    recovered_salts { [1, 2] }
    rejected { 1 }
    time_start { Faker::Time.backward(days: 14, period: :evening) }
    estimated_stop { Faker::Time.forward(days: 23, period: :morning) }

    after(:create) do |hashcat_status|
      create(:hashcat_guess, hashcat_status: hashcat_status) if hashcat_status.hashcat_guess.nil?
      create_list(:device_status, 2, hashcat_status: hashcat_status) if hashcat_status.device_statuses.empty?
      hashcat_status.reload
    end
  end
end
