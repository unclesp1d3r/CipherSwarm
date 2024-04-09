# frozen_string_literal: true

class CreateHashItems < ActiveRecord::Migration[7.1]
  def change
    create_table :hash_items do |t|
      t.boolean :cracked, default: false, comment: "Is the hash cracked?", index: true, null: false
      t.string :plain_text, default: nil, comment: "Plaintext value of the hash"
      t.datetime :cracked_time, default: nil, comment: "Time when the hash was cracked"
      t.text :hash_value, null: false, comment: "Hash value"
      t.text :salt, default: nil, comment: "Salt of the hash"
      t.belongs_to :hash_list, null: false, foreign_key: true
      t.string :metadata_fields, array: true, default: nil, comment: "Metadata fields of the hash item"

      t.timestamps
    end
  end
end
