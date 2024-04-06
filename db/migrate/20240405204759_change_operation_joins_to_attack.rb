# frozen_string_literal: true

class ChangeOperationJoinsToAttack < ActiveRecord::Migration[7.1]
  def change
    drop_join_table :operations, :word_lists
    drop_join_table :operations, :rule_lists
    create_join_table :attacks, :word_lists
    create_join_table :attacks, :rule_lists

    rename_column :tasks, :operation_id, :attack_id
  end
end
