class ChangeLineCountToBigIntInRuleList < ActiveRecord::Migration[7.1]
  def change
    change_column :rule_lists, :line_count, :bigint
  end
end
