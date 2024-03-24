# == Schema Information
#
# Table name: hashcat_benchmarks
#
#  id                                                                  :bigint           not null, primary key
#  benchmark_date(The date and time the benchmark was performed.)      :datetime         not null
#  device(The device used for the benchmark.)                          :integer
#  hash_speed(The speed of the benchmark. In hashes per second.)       :float
#  hash_type(The hashcat hash type.)                                   :integer          not null
#  runtime(The time taken to complete the benchmark. In milliseconds.) :integer
#  created_at                                                          :datetime         not null
#  updated_at                                                          :datetime         not null
#  agent_id                                                            :bigint           not null, indexed
#
# Indexes
#
#  index_hashcat_benchmarks_on_agent_id  (agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#
FactoryBot.define do
  factory :hashcat_benchmark do
    agent { nil }
    hash_type { 1 }
    benchmark_date { "2024-03-22 12:42:24" }
    value { "MyString" }
  end
end
