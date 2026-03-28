# frozen_string_literal: true

class AddCachedProgressToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :cached_progress_pct, :decimal,
               precision: 5, scale: 2, null: true,
               comment: "Denormalized progress percentage from latest HashcatStatus"
  end
end
