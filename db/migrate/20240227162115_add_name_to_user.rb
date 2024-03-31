class AddNameToUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :name, :string,
               null: false, comment: "Unique username. Used for login.",
               default: -> { "md5((random())::text)" } # The default value is a random string and should never be used.
    add_index :users, :name, unique: true
  end
end
