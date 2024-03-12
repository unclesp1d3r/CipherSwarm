class AddProcessedToHashList < ActiveRecord::Migration[7.1]
  def change
    add_column :hash_lists, :processed, :boolean, default: false,
               comment: 'Is the hash list processed into hash items?'
  end
end
