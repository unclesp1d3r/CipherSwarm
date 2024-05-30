# frozen_string_literal: true

class ChangeAgentsNameNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :agents, :name, false
  end
end
