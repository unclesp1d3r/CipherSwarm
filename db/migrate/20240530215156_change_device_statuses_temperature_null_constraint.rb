# frozen_string_literal: true

class ChangeDeviceStatusesTemperatureNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :device_statuses, :temperature, false
  end
end
