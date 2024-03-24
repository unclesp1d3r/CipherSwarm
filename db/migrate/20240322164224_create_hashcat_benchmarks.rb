class CreateHashcatBenchmarks < ActiveRecord::Migration[7.1]
  def change
    create_table :hashcat_benchmarks do |t|
      t.belongs_to :agent, null: false, foreign_key: true
      t.integer :hash_type, null: false, comment: "The hashcat hash type."
      t.datetime :benchmark_date, null: false, comment: "The date and time the benchmark was performed."
      t.string :value, null: false, comment: "The hashcat benchmark value."

      t.timestamps
    end
  end
end
