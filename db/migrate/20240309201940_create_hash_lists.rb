# frozen_string_literal: true

class CreateHashLists < ActiveRecord::Migration[7.1]
  def change
    create_table :hash_lists do |t|
      t.string :name, null: false, comment: "Name of the hash list", index: { unique: true }
      t.text :description, comment: "Description of the hash list"
      t.boolean :sensitive, default: false, comment: "Is the hash list sensitive?", null: false
      t.integer :hash_mode, null: false, comment: "Hash mode of the hash list (hashcat mode)", index: { unique: false }
      t.belongs_to :project, null: false, foreign_key: true, comment: "Project that the hash list belongs to"

      t.timestamps
    end
  end
end
