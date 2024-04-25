# frozen_string_literal: true

class MakeDeviceSpeedABigInt < ActiveRecord::Migration[7.1]
  def down
    change_column :device_statuses, :speed, :integer
  end

  def up
    change_column :device_statuses, :speed, :bigint
  end
end
