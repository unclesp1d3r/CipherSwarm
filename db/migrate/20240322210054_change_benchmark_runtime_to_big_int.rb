class ChangeBenchmarkRuntimeToBigInt < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      change_column :hashcat_benchmarks, :runtime, :float, comment: "The time taken to complete the benchmark. In seconds." do
        dir.up do
        end
        dir.down do
          # Benchmarks can be re-run if they are over 100000 seconds
          HashcatBenchmark.where("runtime > 100000") # Remove any benchmarks that are over 100000 seconds
        end
      end
    end
  end
end
