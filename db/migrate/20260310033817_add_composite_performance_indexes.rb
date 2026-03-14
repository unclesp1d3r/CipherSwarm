# frozen_string_literal: true

class AddCompositePerformanceIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Composite index for hash_items queries that filter by hash_list and attack
    # (e.g., "cracked items for attack X in hash_list Y")
    add_index :hash_items, %i[hash_list_id attack_id],
              name: "index_hash_items_on_hash_list_id_and_attack_id",
              algorithm: :concurrently,
              if_not_exists: true

    # Composite index for task queries filtered by attack and state
    # (e.g., finding pending/running tasks for a specific attack)
    add_index :tasks, %i[attack_id state],
              name: "index_tasks_on_attack_id_and_state",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
