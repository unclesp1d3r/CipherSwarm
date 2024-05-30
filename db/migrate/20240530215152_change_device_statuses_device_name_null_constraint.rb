# frozen_string_literal: true

class ChangeDeviceStatusesDeviceNameNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :device_statuses, :device_name, false
  end
end
