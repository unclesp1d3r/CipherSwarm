# frozen_string_literal: true

# Migration to add preemption tracking to tasks
class AddPreemptionTrackingToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :preemption_count, :integer, default: 0, null: false
    add_index :tasks, :preemption_count
  end
end
