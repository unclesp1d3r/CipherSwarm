# frozen_string_literal: true

class RemoveAllowDeviceToChangeNameFromAgent < ActiveRecord::Migration[7.1]
  def change
    remove_column :agents, :allow_device_to_change_name, :boolean
  end
end
