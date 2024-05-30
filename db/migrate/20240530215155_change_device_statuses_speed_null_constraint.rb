# frozen_string_literal: true

class ChangeDeviceStatusesSpeedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :device_statuses, :speed, false
  end
end
