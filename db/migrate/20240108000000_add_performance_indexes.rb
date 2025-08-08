# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # Add composite index for frequent hash lookups in submit_crack method
    add_index :hash_items, [:hash_value, :hash_list_id], name: 'index_hash_items_on_hash_value_and_hash_list_id'
    
    # Add composite index for cracked hash lookups (used in ProcessHashListJob)
    add_index :hash_items, [:hash_value, :cracked], name: 'index_hash_items_on_hash_value_and_cracked'
    
    # Add index for agent state filtering
    add_index :agents, [:state, :last_seen_at], name: 'index_agents_on_state_and_last_seen_at'
    
    # Add index for task activity timestamp (used in inactive_for scope)
    add_index :tasks, [:activity_timestamp], name: 'index_tasks_on_activity_timestamp'
  end
end
