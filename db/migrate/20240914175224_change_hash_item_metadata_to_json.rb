# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class ChangeHashItemMetadataToJson < ActiveRecord::Migration[7.2]
  def change
    change_table :hash_items, bulk: true do |t|
      t.remove :metadata_fields, type: :array
      t.column :metadata, :jsonb, default: {}, null: false, comment: "Optional metadata fields for the hash item."
    end
  end
end
