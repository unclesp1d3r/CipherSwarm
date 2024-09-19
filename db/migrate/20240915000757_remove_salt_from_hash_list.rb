# frozen_string_literal: true

class RemoveSaltFromHashList < ActiveRecord::Migration[7.2]
  def change
    # This column is a hold over from when we were trying for full hashtopolis compatibility.
    # We are not going to use it, so we are removing it.
    remove_column :hash_lists, :salt, :boolean
  end
end
