# frozen_string_literal: true

class AddUniqueIndexToAgentCustomLabel < ActiveRecord::Migration[7.2]
  def change
    add_index :agents, :custom_label, unique: true
  end
end
