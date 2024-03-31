class CreateHashcatGuesses < ActiveRecord::Migration[7.1]
  def change
    create_table :hashcat_guesses do |t|
      t.belongs_to :hashcat_status, null: false, foreign_key: true
      t.string :guess_base, comment: "The base value used for the guess (for example, the mask)"
      t.bigint :guess_base_count, comment: "The number of times the base value was used"
      t.bigint :guess_base_offset, comment: "The offset of the base value"
      t.decimal :guess_base_percentage, comment: "The percentage completion of the base value"
      t.string :guess_mod, comment: "The modifier used for the guess (for example, the wordlist)"
      t.bigint :guess_mod_count, comment: "The number of times the modifier was used"
      t.bigint :guess_mod_offset, comment: "The offset of the modifier"
      t.decimal :guess_mod_percentage, comment: "The percentage completion of the modifier"
      t.integer :guess_mode, comment: "The mode used for the guess"

      t.timestamps
    end
  end
end
