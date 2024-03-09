class CreateCrackerBinaries < ActiveRecord::Migration[7.1]
  def change
    create_table :cracker_binaries do |t|
      t.string :version
      t.boolean :active
      t.references :cracker, null: false, foreign_key: true

      t.timestamps
    end
  end
end
