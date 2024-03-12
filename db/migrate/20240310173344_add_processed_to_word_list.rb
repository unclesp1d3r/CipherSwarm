class AddProcessedToWordList < ActiveRecord::Migration[7.1]
  def change
    add_column :word_lists, :processed, :boolean, default: false
    add_index :word_lists, :processed, unique: false
  end
end
