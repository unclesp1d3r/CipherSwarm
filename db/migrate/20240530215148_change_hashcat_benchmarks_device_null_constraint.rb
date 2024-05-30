# frozen_string_literal: true

class ChangeHashcatBenchmarksDeviceNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_benchmarks, :device, false
  end
end
