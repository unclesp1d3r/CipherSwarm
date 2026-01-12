# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddAdditionalPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # Add index on hash_items.cracked_time for recent cracks queries
    add_index :hash_items, [:cracked_time], name: "index_hash_items_on_cracked_time"

    # Add index on agent_errors.created_at for error tracking
    add_index :agent_errors, [:created_at], name: "index_agent_errors_on_created_at"

    # Add index on hashcat_statuses.time for status queries
    add_index :hashcat_statuses, [:time], name: "index_hashcat_statuses_on_time"

    # Add composite index on tasks(agent_id, state) for agent task filtering
    add_index :tasks, %i[agent_id state], name: "index_tasks_on_agent_id_and_state"
  end
end
