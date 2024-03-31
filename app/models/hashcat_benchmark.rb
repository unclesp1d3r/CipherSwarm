# == Schema Information
#
# Table name: hashcat_benchmarks
#
#  id                                                                  :bigint           not null, primary key
#  benchmark_date(The date and time the benchmark was performed.)      :datetime         not null, indexed => [agent_id, hash_type]
#  device(The device used for the benchmark.)                          :integer
#  hash_speed(The speed of the benchmark. In hashes per second.)       :float
#  hash_type(The hashcat hash type.)                                   :integer          not null, indexed => [agent_id, benchmark_date]
#  runtime(The time taken to complete the benchmark. In milliseconds.) :bigint
#  created_at                                                          :datetime         not null
#  updated_at                                                          :datetime         not null
#  agent_id                                                            :bigint           not null, indexed => [benchmark_date, hash_type], indexed
#
# Indexes
#
#  idx_on_agent_id_benchmark_date_hash_type_a667ecb9be  (agent_id,benchmark_date,hash_type) UNIQUE
#  index_hashcat_benchmarks_on_agent_id                 (agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#
class HashcatBenchmark < ApplicationRecord
  belongs_to :agent
  validates :benchmark_date, presence: true
  validates :device, presence: true
  validates :hash_speed, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :hash_type, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :runtime, presence: true, numericality: { only_integer: true }
  validates :agent, uniqueness: { scope: %i[benchmark_date hash_type] }
  validates :hash_speed, numericality: { greater_than: 0 }
  validates :runtime, numericality: { greater_than: 0 }
  validates :device, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :hash_type, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
