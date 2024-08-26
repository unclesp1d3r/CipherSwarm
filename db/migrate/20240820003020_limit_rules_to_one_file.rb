# frozen_string_literal: true

class LimitRulesToOneFile < ActiveRecord::Migration[7.1]
  def change
    drop_join_table :attacks, :rule_lists, comment: "Join table for attacks and rule lists."
    add_reference :attacks, :rule_list, comment: "The rule list used for the attack.", foreign_key: true
  end
end
