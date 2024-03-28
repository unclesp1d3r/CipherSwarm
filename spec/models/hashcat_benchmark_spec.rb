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
  context 'associations' do
    it { should belong_to(:agent) }
  end
  context 'validations' do
    it { should validate_presence_of(:benchmark_date) }
    it { should validate_presence_of(:device) }
    it { should validate_presence_of(:hash_speed) }
    it { should validate_presence_of(:hash_type) }
    it { should validate_presence_of(:runtime) }
    it { should validate_presence_of(:agent) }
    it { should validate_numericality_of(:hash_speed).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:runtime).is_greater_than(0) }
    it { should validate_numericality_of(:device).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:hash_type).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:hash_type).only_integer }
    it { should validate_numericality_of(:device).only_integer }
    it { should validate_numericality_of(:runtime).only_integer }
    context 'uniqueness' do
      subject { create(:hashcat_benchmark) }
      it { should validate_uniqueness_of(:agent).scoped_to(:benchmark_date, :hash_type) }
    end
  end
end
