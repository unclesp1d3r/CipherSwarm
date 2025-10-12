# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: hashcat_benchmarks
#
#  id                                                                  :bigint           not null, primary key
#  benchmark_date(The date and time the benchmark was performed.)      :datetime         not null, uniquely indexed => [agent_id, hash_type]
#  device(The device used for the benchmark.)                          :integer          not null
#  hash_speed(The speed of the benchmark. In hashes per second.)       :float            not null
#  hash_type(The hashcat hash type.)                                   :integer          not null, uniquely indexed => [agent_id, benchmark_date]
#  runtime(The time taken to complete the benchmark. In milliseconds.) :bigint           not null
#  created_at                                                          :datetime         not null
#  updated_at                                                          :datetime         not null
#  agent_id                                                            :bigint           not null, uniquely indexed => [benchmark_date, hash_type]
#
# Indexes
#
#  idx_on_agent_id_benchmark_date_hash_type_a667ecb9be  (agent_id,benchmark_date,hash_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#
FactoryBot.define do
  sequence(:benchmark_timestamp) { |n| Time.current - n.seconds }

  factory :hashcat_benchmark do
    agent
    hash_type { 0 }
    benchmark_date { generate(:benchmark_timestamp) }
    device { 1 }
    hash_speed { 1000000.0 }
    runtime { Faker::Number.number(digits: 10) }
  end
end
