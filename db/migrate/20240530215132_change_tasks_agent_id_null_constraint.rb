# frozen_string_literal: true

class ChangeTasksAgentIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :tasks, :agent_id, false
  end
end
