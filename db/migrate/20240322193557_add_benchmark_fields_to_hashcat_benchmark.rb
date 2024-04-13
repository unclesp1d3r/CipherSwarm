# frozen_string_literal: true

class AddBenchmarkFieldsToHashcatBenchmark < ActiveRecord::Migration[7.1]
  def change
    add_column :hashcat_benchmarks, :device, :integer, comment: "The device used for the benchmark."
    add_column :hashcat_benchmarks, :hash_speed, :float, comment: "The speed of the benchmark. In hashes per second."
    add_column :hashcat_benchmarks, :runtime, :integer,
               comment: "The time taken to complete the benchmark. In milliseconds."
    remove_column :hashcat_benchmarks, :value, :string
  end
end
