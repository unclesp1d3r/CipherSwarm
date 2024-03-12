class AddSaltToHashList < ActiveRecord::Migration[7.1]
  def change
    add_column :hash_lists, :salt, :boolean, default: false,
               comment: 'Does the hash list contain a salt?'
  end
end
