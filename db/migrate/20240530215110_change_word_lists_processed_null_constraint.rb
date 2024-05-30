# frozen_string_literal: true

class ChangeWordListsProcessedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :word_lists, :processed, false
  end
end
