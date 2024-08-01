# frozen_string_literal: true

class RemoveUnusedAgentParameters < ActiveRecord::Migration[7.1]
  def change
    remove_column :agents, :command_parameters, :text
    remove_column :agents, :cpu_only, :boolean, default: false, null: false
    remove_column :agents, :ignore_errors, :boolean, default: false, null: false
    remove_column :agents, :trusted, :boolean, default: false, null: false
  end
end
