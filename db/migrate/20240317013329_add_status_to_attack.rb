class AddStatusToAttack < ActiveRecord::Migration[7.1]
  def change
    add_column :operations, :status, :integer, default: 0, null: false, comment: "Operation status"
    add_index :operations, :status
  end
end
