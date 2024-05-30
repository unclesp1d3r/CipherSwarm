# frozen_string_literal: true

class ChangeHashItemsCrackedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hash_items, :cracked, false
  end
end
