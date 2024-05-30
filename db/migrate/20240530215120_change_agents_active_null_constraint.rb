# frozen_string_literal: true

class ChangeAgentsActiveNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :agents, :active, false
  end
end
