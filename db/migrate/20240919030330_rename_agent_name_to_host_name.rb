# frozen_string_literal: true

class RenameAgentNameToHostName < ActiveRecord::Migration[7.0]
  def change
    rename_column :agents, :name, :host_name
  end
end
