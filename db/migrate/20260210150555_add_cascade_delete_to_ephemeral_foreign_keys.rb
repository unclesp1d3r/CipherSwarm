# frozen_string_literal: true

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
