# frozen_string_literal: true

class ChangeHashcatBenchmarksHashSpeedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_benchmarks, :hash_speed, false
  end
end
