# frozen_string_literal: true

class CreateDeviceStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :device_statuses do |t|
      t.belongs_to :hashcat_status, null: false, foreign_key: true
      t.integer :device_id, comment: "Device ID"
      t.string :device_name, comment: "Device Name"
      t.string :device_type, comment: "Device Type"
      t.integer :speed, comment: "Speed "
      t.integer :utilization, comment: "Utilization Percentage"
      t.integer :temperature, comment: "Temperature in Celsius (-1 if not available)"

      t.timestamps
    end
  end
end
