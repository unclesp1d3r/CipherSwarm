# frozen_string_literal: true

class AddDevicesToAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :agents, :devices, :string,
               array: true, default: [],
               comment: "Devices that the agent supports"
  end
end
