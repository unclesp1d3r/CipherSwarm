class CreateOperationRuleListJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :operations, :rule_lists do |t|
      t.index [ :operation_id, :rule_list_id ], name: "index_operations_rule_lists_on_operation_id_and_rule_list_id"
      t.index [ :rule_list_id, :operation_id ], name: "index_operations_rule_lists_on_rule_list_id_and_operation_id"
    end
  end
end
