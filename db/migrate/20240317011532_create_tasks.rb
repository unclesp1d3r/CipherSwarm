class CreateTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :tasks do |t|
      t.belongs_to :operation, null: false, foreign_key: true, comment: "The attack that the task is associated with."
      t.belongs_to :agent, null: true, foreign_key: true, comment: "The agent that the task is assigned to, if any."
      t.datetime :start_date, null: true, comment: "The date and time that the task was started."

      t.timestamps
    end
  end
end
