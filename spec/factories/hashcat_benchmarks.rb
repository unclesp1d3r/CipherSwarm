# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hashcat_benchmarks
#
#  id                                                                  :bigint           not null, primary key
#  benchmark_date(The date and time the benchmark was performed.)      :datetime         not null
#  device(The device used for the benchmark.)                          :integer          not null, uniquely indexed => [agent_id, hash_type]
#  hash_speed(The speed of the benchmark. In hashes per second.)       :float            not null
#  hash_type(The hashcat hash type.)                                   :integer          not null, uniquely indexed => [agent_id, device]
#  runtime(The time taken to complete the benchmark. In milliseconds.) :bigint           not null
#  created_at                                                          :datetime         not null
#  updated_at                                                          :datetime         not null
#  agent_id                                                            :bigint           not null, uniquely indexed => [hash_type, device]
#
# Indexes
#
#  index_hashcat_benchmarks_on_agent_id_and_hash_type_and_device  (agent_id,hash_type,device) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id) ON DELETE => cascade
#
FactoryBot.define do
  sequence(:benchmark_timestamp) { |n| Time.current - n.seconds }
  sequence(:benchmark_hash_type) { |n| n }

  factory :hashcat_benchmark do
    agent
    hash_type { generate(:benchmark_hash_type) }
    benchmark_date { generate(:benchmark_timestamp) }
    device { 1 }
    hash_speed { 1000000.0 }
    runtime { Faker::Number.number(digits: 10) }
  end
end
