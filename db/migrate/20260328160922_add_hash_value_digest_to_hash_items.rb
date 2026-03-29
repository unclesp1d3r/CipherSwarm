# frozen_string_literal: true

class AddHashValueDigestToHashItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :hash_items, :hash_value_digest, :string, limit: 32, null: true,
                                                         comment: "MD5 fingerprint of hash_value for B-tree indexing"

    # Batch the backfill to avoid holding a long-running write lock on the entire table.
    # Each iteration updates up to 10,000 rows in its own implicit transaction.
    loop do
      rows = execute(<<~SQL.squish).cmd_tuples
        UPDATE hash_items SET hash_value_digest = md5(hash_value)
        WHERE id IN (
          SELECT id FROM hash_items WHERE hash_value_digest IS NULL LIMIT 10000
        )
      SQL
      break if rows.zero?
    end

    change_column_null :hash_items, :hash_value_digest, false

    # Build new indexes BEFORE dropping old ones to avoid a window with no indexes.
    add_index :hash_items, %i[hash_value_digest cracked],
      name: "index_hash_items_on_hash_value_digest_and_cracked", algorithm: :concurrently
    add_index :hash_items, %i[hash_value_digest hash_list_id],
      name: "index_hash_items_on_hash_value_digest_and_hash_list_id", algorithm: :concurrently

    remove_index :hash_items, name: "index_hash_items_on_hash_value_and_cracked", algorithm: :concurrently
    remove_index :hash_items, name: "index_hash_items_on_hash_value_and_hash_list_id", algorithm: :concurrently
  end

  def down
    # NOTE: Rollback re-creates B-tree indexes on hash_value (TEXT column).
    # This will fail for any row with hash_value longer than 2704 bytes,
    # which is the original problem this migration solves (issue #789).
    if execute("SELECT 1 FROM hash_items WHERE octet_length(hash_value) > 2704 LIMIT 1").any?
      raise ActiveRecord::IrreversibleMigration,
        "Cannot rollback: hash_items contains hash_value entries exceeding 2704 bytes. " \
        "Re-creating B-tree indexes on hash_value would fail."
    end

    remove_index :hash_items, name: "index_hash_items_on_hash_value_digest_and_cracked", algorithm: :concurrently
    remove_index :hash_items, name: "index_hash_items_on_hash_value_digest_and_hash_list_id", algorithm: :concurrently

    add_index :hash_items, %i[hash_value cracked],
      name: "index_hash_items_on_hash_value_and_cracked", algorithm: :concurrently
    add_index :hash_items, %i[hash_value hash_list_id],
      name: "index_hash_items_on_hash_value_and_hash_list_id", algorithm: :concurrently

    remove_column :hash_items, :hash_value_digest
  end
end
