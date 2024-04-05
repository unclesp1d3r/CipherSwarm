class AddPositionToAttack < ActiveRecord::Migration[7.1]
  def change
    add_column :attacks, :position, :integer, null: false, default: 0,
               comment: "The position of the attack in the campaign."
    add_index :attacks, [ :campaign_id, :position ], unique: true
  end
end
