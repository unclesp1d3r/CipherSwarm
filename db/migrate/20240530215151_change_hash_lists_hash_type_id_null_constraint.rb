# frozen_string_literal: true

class ChangeHashListsHashTypeIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hash_lists, :hash_type_id, false
  end
end
