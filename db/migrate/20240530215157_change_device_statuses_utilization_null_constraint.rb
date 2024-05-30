# frozen_string_literal: true

class ChangeDeviceStatusesUtilizationNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :device_statuses, :utilization, false
  end
end
