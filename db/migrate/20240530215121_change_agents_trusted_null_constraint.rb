# frozen_string_literal: true

class ChangeAgentsTrustedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :agents, :trusted, false
  end
end
