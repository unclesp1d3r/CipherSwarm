class AddCrackerToOperation < ActiveRecord::Migration[7.1]
  def change
    add_reference :operations, :cracker, foreign_key: true, null: true
  end
end
