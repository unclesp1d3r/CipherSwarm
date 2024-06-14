# frozen_string_literal: true

class AddStateToAgent < ActiveRecord::Migration[7.1]
  def change
    add_column :agents, :state, :string, default: "pending", null: false, comment: "The state of the agent"
    add_index :agents, :state
  end
end
