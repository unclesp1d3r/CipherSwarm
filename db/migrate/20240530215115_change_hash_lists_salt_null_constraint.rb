# frozen_string_literal: true

class ChangeHashListsSaltNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hash_lists, :salt, false
  end
end
