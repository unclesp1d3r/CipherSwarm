# frozen_string_literal: true

class AddStateToTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :state, :string, default: "pending", null: false
    add_index :tasks, :state
  end
end
