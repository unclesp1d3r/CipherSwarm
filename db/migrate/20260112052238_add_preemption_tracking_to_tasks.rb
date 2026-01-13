# frozen_string_literal: true

# Migration to add preemption tracking to tasks
class AddPreemptionTrackingToTasks < ActiveRecord::Migration[8.0]
  ##
  # Adds preemption tracking to the tasks table by creating a non-null integer
  # column `preemption_count` with a default value of 0 and an index on that column.
  def change
    add_column :tasks, :preemption_count, :integer, default: 0, null: false
    add_index :tasks, :preemption_count
  end
end