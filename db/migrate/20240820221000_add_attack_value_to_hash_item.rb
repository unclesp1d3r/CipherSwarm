# frozen_string_literal: true

class AddAttackValueToHashItem < ActiveRecord::Migration[7.1]
  def change
    add_reference :hash_items, :attack, null: true, foreign_key: true, comment: "The attack that cracked this hash"
  end
end
