# frozen_string_literal: true

class AddPausedAtToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :paused_at, :datetime
    add_index :tasks, :paused_at, where: "state = 'paused'"
  end
end
