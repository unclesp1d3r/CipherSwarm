class AddUniquenessConstraintOnHashItem < ActiveRecord::Migration[7.1]
  def change
    add_index :hash_items, [ :hash_value, :salt, :hash_list_id ], unique: true
  end
end
