# frozen_string_literal: true

# Version: 0.1
class CreateMaskLists < ActiveRecord::Migration[7.1]
  def change
    create_table :mask_lists do |t|
      t.text :description, comment: "Description of the mask list"
      t.bigint :line_count, comment: "Number of lines in the mask list", null: true
      t.string :name, null: false, comment: "Name of the mask list", index: { unique: true }, limit: 255
      t.boolean :processed, null: false, default: false, comment: "Has the mask list been processed?", index: true
      t.boolean :sensitive, null: false, comment: "Is the mask list sensitive?", default: false
      t.timestamps
    end
  end
end
