# frozen_string_literal: true

class ChangeAgentsUserIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :agents, :user_id, false
  end
end
