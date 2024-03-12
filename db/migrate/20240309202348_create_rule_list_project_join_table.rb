class CreateRuleListProjectJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :rule_lists, :projects do |t|
      t.index :rule_list_id
      t.index :project_id
    end
  end
end
