class AddProcessedToRuleList < ActiveRecord::Migration[7.1]
  def change
    add_column :rule_lists, :processed, :boolean, default: false
  end
end
