# frozen_string_literal: true

class AddCascadeDeleteToRemainingForeignKeys < ActiveRecord::Migration[8.0]
  def up
    replace_foreign_key :hash_items, :hash_lists, column: :hash_list_id, on_delete: :cascade
    replace_foreign_key :hash_lists, :projects, column: :project_id, on_delete: :cascade
    replace_foreign_key :project_users, :projects, column: :project_id, on_delete: :cascade
    replace_foreign_key :project_users, :users, column: :user_id, on_delete: :cascade
  end

  def down
    replace_foreign_key :hash_items, :hash_lists, column: :hash_list_id
    replace_foreign_key :hash_lists, :projects, column: :project_id
    replace_foreign_key :project_users, :projects, column: :project_id
    replace_foreign_key :project_users, :users, column: :user_id
  end

  private

  def replace_foreign_key(from_table, to_table, column:, on_delete: nil)
    remove_foreign_key from_table, to_table, column: column
    add_foreign_key from_table, to_table, column: column, on_delete: on_delete
  end
end
