# frozen_string_literal: true

class AddCustomLabelToAgents < ActiveRecord::Migration[7.0]
  def change
    add_column :agents, :custom_label, :string, comment: "Custom label for the agent"
  end
end
