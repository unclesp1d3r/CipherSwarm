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
require "rails_helper"

RSpec.describe HashcatBenchmark do
  describe "associations" do
    it { is_expected.to belong_to(:agent) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:benchmark_date) }
    it { is_expected.to validate_presence_of(:device) }
    it { is_expected.to validate_presence_of(:hash_speed) }
    it { is_expected.to validate_presence_of(:hash_type) }
    it { is_expected.to validate_presence_of(:runtime) }
    it { is_expected.to validate_numericality_of(:hash_speed).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:runtime).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:device).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:hash_type).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:hash_type).only_integer }
    it { is_expected.to validate_numericality_of(:device).only_integer }
    it { is_expected.to validate_numericality_of(:runtime).only_integer }

    describe "uniqueness" do
      subject { create(:hashcat_benchmark) }

      it { is_expected.to validate_uniqueness_of(:agent).scoped_to(:benchmark_date, :hash_type) }
    end
  end
end
