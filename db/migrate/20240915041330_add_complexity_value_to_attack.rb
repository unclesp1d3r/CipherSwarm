# frozen_string_literal: true

class AddComplexityValueToAttack < ActiveRecord::Migration[7.2]
  def change
    add_column :attacks, :complexity_value, :numeric, default: 0, null: false, comment: 'Complexity value of the attack'
    add_index :attacks, :complexity_value

    # Update the complexity value for all the attacks in the database
    Attack.find_each do |attack|
      attack.force_complexity_update
    end
  end
end
