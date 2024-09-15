# frozen_string_literal: true

class AddCreatorValueToLists < ActiveRecord::Migration[7.2]
  def change
    add_reference :word_lists, :creator, foreign_key: { to_table: :users }, comment: "The user who created this list"
    add_reference :rule_lists, :creator, foreign_key: { to_table: :users }, comment: "The user who created this list"
    add_reference :mask_lists, :creator, foreign_key: { to_table: :users }, comment: "The user who created this list"
  end
end
