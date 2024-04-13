# frozen_string_literal: true

class CreateRuleLists < ActiveRecord::Migration[7.1]
  def change
    create_table :rule_lists do |t|
      t.string :name, null: false, comment: "Name of the rule list", index: { unique: true }
      t.text :description, comment: "Description of the rule list"
      t.integer :line_count, default: 0, comment: "Number of lines in the rule list"
      t.boolean :sensitive, default: false, comment: "Sensitive rule list", null: false

      t.timestamps
    end
  end
end
