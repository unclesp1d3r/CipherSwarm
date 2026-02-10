# frozen_string_literal: true

# REASONING:
#   Why: Parent-child FK constraints (hash_items→hash_lists, hash_lists→projects,
#     project_users→projects/users) lacked DB-level `on_delete` rules. Rails
#     `dependent: :destroy` handles these in normal flows, but DB-level cascades
#     from upstream tables could leave orphaned rows.
#   Alternatives Considered:
#     - Leave as-is: acceptable since these parents are rarely bulk-deleted, but
#       inconsistent with the ephemeral FK migration.
#   Decision: Add `on_delete: :cascade` for consistency and defense-in-depth.
#     All cascade directions are parent→child (user-created parent deletes its
#     own children), so there is no risk of ephemeral data deleting user content.
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
