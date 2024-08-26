# frozen_string_literal: true

class LimitMaskListsToOneFile < ActiveRecord::Migration[7.1]
  def change
    drop_join_table :attacks, :mask_lists, comment: "Join table for attacks and mask lists."
    add_reference :attacks, :mask_list, comment: "The mask list used for the attack.", foreign_key: true
  end
end
