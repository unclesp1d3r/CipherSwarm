# frozen_string_literal: true

class AddHashValueDigestToHashItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :hash_items, :hash_value_digest, :string, limit: 32, null: true,
                                                         comment: "MD5 fingerprint of hash_value for B-tree indexing"

    execute <<~SQL.squish
      UPDATE hash_items SET hash_value_digest = md5(hash_value) WHERE hash_value_digest IS NULL
    SQL

    remove_index :hash_items, name: "index_hash_items_on_hash_value_and_cracked", algorithm: :concurrently
    remove_index :hash_items, name: "index_hash_items_on_hash_value_and_hash_list_id", algorithm: :concurrently

    add_index :hash_items, %i[hash_value_digest cracked],
      name: "index_hash_items_on_hash_value_digest_and_cracked", algorithm: :concurrently
    add_index :hash_items, %i[hash_value_digest hash_list_id],
      name: "index_hash_items_on_hash_value_digest_and_hash_list_id", algorithm: :concurrently
  end

  def down
    remove_index :hash_items, name: "index_hash_items_on_hash_value_digest_and_cracked", algorithm: :concurrently
    remove_index :hash_items, name: "index_hash_items_on_hash_value_digest_and_hash_list_id", algorithm: :concurrently

    add_index :hash_items, %i[hash_value cracked],
      name: "index_hash_items_on_hash_value_and_cracked", algorithm: :concurrently
    add_index :hash_items, %i[hash_value hash_list_id],
      name: "index_hash_items_on_hash_value_and_hash_list_id", algorithm: :concurrently

    remove_column :hash_items, :hash_value_digest
  end
end
