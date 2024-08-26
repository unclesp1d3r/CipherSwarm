# frozen_string_literal: true

class AddCascadeToAttackFk < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :attacks, :word_lists
    add_foreign_key :attacks, :word_lists, on_delete: :cascade
  end
end
