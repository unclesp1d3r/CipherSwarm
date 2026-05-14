# frozen_string_literal: true

# Adds a partial index supporting `uncracked_count_uncached` and other
# `WHERE cracked = false` queries that fire from state-machine completion
# guards on the crack-submission hot path. See Issue #570.
#
# Created concurrently and outside the migration transaction so the table
# stays writable during rollout.
class AddUncrackedHashItemsIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :hash_items,
              :hash_list_id,
              where: "cracked = false",
              name: "index_hash_items_on_hash_list_id_uncracked",
              algorithm: :concurrently
  end
end
