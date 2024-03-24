class ChangeBenchmarkRuntimeToBigInt < ActiveRecord::Migration[7.1]
  def change
    change_column :hashcat_benchmarks, :runtime, :bigint, comment: "The time taken to complete the benchmark. In milliseconds."
  end
end
