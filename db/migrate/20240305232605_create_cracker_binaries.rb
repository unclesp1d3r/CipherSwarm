# frozen_string_literal: true

class CreateCrackerBinaries < ActiveRecord::Migration[7.1]
  def change
    create_table :cracker_binaries do |t|
      t.string :version, null: false, comment: "Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1"
      t.boolean :active, default: true, comment: "Is the cracker binary active?", null: false
      t.references :cracker, null: false, foreign_key: true

      t.timestamps
    end

    add_index :cracker_binaries, %i[version cracker_id], unique: true
  end
end
