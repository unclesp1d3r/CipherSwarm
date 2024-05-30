# frozen_string_literal: true

class ChangeHashcatBenchmarksRuntimeNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_benchmarks, :runtime, false
  end
end
