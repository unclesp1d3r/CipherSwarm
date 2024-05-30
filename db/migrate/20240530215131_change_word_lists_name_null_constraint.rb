# frozen_string_literal: true

class ChangeWordListsNameNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :word_lists, :name, false
  end
end
