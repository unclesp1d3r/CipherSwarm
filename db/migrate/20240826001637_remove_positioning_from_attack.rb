# frozen_string_literal: true

class RemovePositioningFromAttack < ActiveRecord::Migration[7.1]
  def change
    remove_index :attacks, name: "index_attacks_on_campaign_id_and_position"
    remove_column :attacks, :position, :integer
  end
end
