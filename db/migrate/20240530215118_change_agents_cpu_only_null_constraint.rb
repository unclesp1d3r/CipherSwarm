# frozen_string_literal: true

class ChangeAgentsCpuOnlyNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :agents, :cpu_only, false
  end
end
