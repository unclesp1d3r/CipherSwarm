class AddAdvancedConfigurationToAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :agents, :advanced_configuration, :jsonb, default: {}, comment: "Advanced configuration for the agent."
  end
end
