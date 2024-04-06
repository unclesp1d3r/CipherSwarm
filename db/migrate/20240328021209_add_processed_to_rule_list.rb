# frozen_string_literal: true

class AddProcessedToRuleList < ActiveRecord::Migration[7.1]
  def change
    add_column :rule_lists, :processed, :boolean, default: false, null: false
  end
end
