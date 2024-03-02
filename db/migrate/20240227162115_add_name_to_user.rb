class AddNameToUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :name, :string,
               null: false, comment: "Unique username. Used for login."
    add_index :users, :name, unique: true
  end
end
