class CreateWordLists < ActiveRecord::Migration[7.1]
  def change
    create_table :word_lists do |t|
      t.string :name, comment: 'Name of the word list', index: { unique: true }
      t.text :description, comment: 'Description of the word list'
      t.integer :line_count, comment: 'Number of lines in the word list'
      t.boolean :sensitive, comment: 'Is the word list sensitive?'
      t.belongs_to :project, null: false, foreign_key: true, comment: 'Project to which the word list belongs'

      t.timestamps
    end
  end
end
