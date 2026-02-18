# frozen_string_literal: true

# REASONING:
#   Why: Ephemeral tables (agent_errors, hashcat_benchmarks, tasks) relied solely on
#     Rails `dependent:` callbacks for cleanup. Bulk deletes (`delete_all`) and DB-level
#     cascades bypass these callbacks, leaving orphaned rows or raising FK violations.
#   Alternatives Considered:
#     - Rails callbacks only: insufficient when delete_all or DB cascades are used.
#     - Separate cleanup jobs per table: higher complexity with more moving parts.
#   Decision: Apply explicit DB `on_delete` rules so referential integrity is enforced
#     regardless of whether deletion goes through Rails or directly through the database.
#   Performance Implications: Negligible; FK cascade/nullify is handled by PostgreSQL
#     during delete operations that would already be touching these rows.
class AddCascadeDeleteToEphemeralForeignKeys < ActiveRecord::Migration[8.0]
  def up
    # High priority: prevent FK violations during cascades
    replace_foreign_key :agent_errors, :tasks, column: :task_id, on_delete: :nullify
    replace_foreign_key :hash_items, :attacks, column: :attack_id, on_delete: :nullify

    # Medium priority: ephemeral data should cascade with parent
    replace_foreign_key :agent_errors, :agents, column: :agent_id, on_delete: :cascade
    replace_foreign_key :hashcat_benchmarks, :agents, column: :agent_id, on_delete: :cascade
    replace_foreign_key :tasks, :agents, column: :agent_id, on_delete: :cascade
    replace_foreign_key :tasks, :agents, column: :claimed_by_agent_id, on_delete: :nullify
  end

  def down
    replace_foreign_key :agent_errors, :tasks, column: :task_id
    replace_foreign_key :hash_items, :attacks, column: :attack_id

    replace_foreign_key :agent_errors, :agents, column: :agent_id
    replace_foreign_key :hashcat_benchmarks, :agents, column: :agent_id
    replace_foreign_key :tasks, :agents, column: :agent_id
    replace_foreign_key :tasks, :agents, column: :claimed_by_agent_id
  end

  private

  def replace_foreign_key(from_table, to_table, column:, on_delete: nil)
    remove_foreign_key from_table, to_table, column: column
    add_foreign_key from_table, to_table, column: column, on_delete: on_delete
  end
end
