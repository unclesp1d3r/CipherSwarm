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
require 'rails_helper'

RSpec.describe HashcatBenchmark, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
