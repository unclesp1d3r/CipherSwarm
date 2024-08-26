# frozen_string_literal: true

class AddCascadeToAttackFkForTasks < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :tasks, :attacks
    add_foreign_key :tasks, :attacks, on_delete: :cascade
  end
end
