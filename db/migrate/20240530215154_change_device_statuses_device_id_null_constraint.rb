# frozen_string_literal: true

class ChangeDeviceStatusesDeviceIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :device_statuses, :device_id, false
  end
end
