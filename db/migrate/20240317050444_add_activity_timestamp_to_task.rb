class AddActivityTimestampToTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :activity_timestamp, :datetime, null: true, comment: "The timestamp of the last activity on the task"
  end
end
