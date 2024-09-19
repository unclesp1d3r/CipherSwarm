# frozen_string_literal: true

class ChangeHashItemMetadataToJson < ActiveRecord::Migration[7.2]
  def change
    remove_column :hash_items, :metadata_fields, :array
    add_column :hash_items, :metadata, :jsonb, default: {}, null: false, comment: "Optional metadata fields for the hash item."
  end
end
