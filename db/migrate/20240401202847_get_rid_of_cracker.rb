class GetRidOfCracker < ActiveRecord::Migration[7.1]
  def change
    reversible do |direction|
      direction.up do
        remove_column :cracker_binaries, :cracker_id
        remove_column :operations, :cracker_id
        drop_table :crackers
      end
      direction.down do
        create_table "crackers", force: :cascade do |t|
          t.string "name", comment: "Name of the cracker", index: { unique: true }
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
        end
        add_column :cracker_binaries, :cracker_id, :bigint, null: false, comment: "The cracker that this binary belongs to", default: 1
        add_column :operations, :cracker_id, :bigint, null: false, comment: "The cracker that this operation is using", default: 1
      end
    end
  end
end
