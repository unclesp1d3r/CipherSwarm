# frozen_string_literal: true

class AddCreatorToAttacks < ActiveRecord::Migration[8.0]
  def change
    add_reference :attacks, :creator, foreign_key: { to_table: :users }, index: true, comment: "The user who created this attack"
  end
end
