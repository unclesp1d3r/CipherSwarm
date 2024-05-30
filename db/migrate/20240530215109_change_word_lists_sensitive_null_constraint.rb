# frozen_string_literal: true

class ChangeWordListsSensitiveNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :word_lists, :sensitive, false
  end
end
