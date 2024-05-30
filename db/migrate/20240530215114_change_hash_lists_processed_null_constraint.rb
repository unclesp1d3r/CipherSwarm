# frozen_string_literal: true

class ChangeHashListsProcessedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hash_lists, :processed, false
  end
end
