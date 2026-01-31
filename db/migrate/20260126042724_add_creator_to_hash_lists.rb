# frozen_string_literal: true

class AddCreatorToHashLists < ActiveRecord::Migration[8.0]
  def change
    add_reference :hash_lists, :creator, foreign_key: { to_table: :users }, index: true, comment: "The user who created this hash list"
  end
end
