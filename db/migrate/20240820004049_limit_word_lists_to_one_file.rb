# frozen_string_literal: true

class LimitWordListsToOneFile < ActiveRecord::Migration[7.1]
  def change
    drop_join_table :attacks, :word_lists, comment: "Join table for attacks and word lists."
    add_reference :attacks, :word_list, comment: "The word list used for the attack.", foreign_key: true
  end
end