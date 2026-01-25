# frozen_string_literal: true

class AddCurrentActivityToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :current_activity, :string, comment: "Current agent activity state (e.g., cracking, waiting, benchmarking)"
    add_index :agents, :current_activity
  end
end
