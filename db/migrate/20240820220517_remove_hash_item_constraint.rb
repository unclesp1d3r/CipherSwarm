# frozen_string_literal: true

class RemoveHashItemConstraint < ActiveRecord::Migration[7.1]
  def change
    remove_index :hash_items, column: ["hash_value", "salt", "hash_list_id"]
  end
end