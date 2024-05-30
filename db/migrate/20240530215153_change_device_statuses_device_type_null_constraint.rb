# frozen_string_literal: true

class ChangeDeviceStatusesDeviceTypeNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :device_statuses, :device_type, false
  end
end
