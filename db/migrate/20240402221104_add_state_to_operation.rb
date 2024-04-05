class AddStateToOperation < ActiveRecord::Migration[7.1]
  def change
    add_column :operations, :state, :string
    add_index :operations, :state
  end
end
