class AddPriorityToAttack < ActiveRecord::Migration[7.1]
  def change
    add_column :operations, :priority,
               :integer, default: 0, null: false,
               comment: "The priority of the attack, higher numbers are higher priority."
  end
end
