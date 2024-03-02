class CreateAgentsProjectsJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :agents, :projects do |t|
      t.index :agent_id
      t.index :project_id
    end
  end
end
