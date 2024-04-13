# frozen_string_literal: true

class AddStatusToTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :status, :integer, default: 0, null: false, comment: "Task status"
    add_index :tasks, :status
  end
end
