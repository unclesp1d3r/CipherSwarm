class AddUniquenessConstraintOnHashcatBenchmark < ActiveRecord::Migration[7.1]
  def change
    add_index :hashcat_benchmarks, [ :agent_id, :benchmark_date, :hash_type ], unique: true
  end
end
