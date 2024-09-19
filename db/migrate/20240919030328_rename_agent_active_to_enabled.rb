# frozen_string_literal: true

class RenameAgentActiveToEnabled < ActiveRecord::Migration[7.2]
  def change
    rename_column :agents, :active, :enabled
  end
end
