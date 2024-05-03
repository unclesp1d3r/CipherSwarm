# frozen_string_literal: true

class CreateHashTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :hash_types do |t|
      t.integer :hashcat_mode, null: false, index: { unique: true }, comment: "The hashcat mode number"
      t.string :name, null: false, index: { unique: true }, comment: "The name of the hash type"
      t.integer :category, default: 0, null: false, comment: "The category of the hash type"
      t.boolean :built_in, default: false, null: false, comment: "Whether the hash type is built-in"
      t.boolean :enabled, default: true, null: false, comment: "Whether the hash type is enabled"
      t.boolean :is_slow, default: false, null: false, comment: "Whether the hash type is slow"

      t.timestamps
    end
  end
end
