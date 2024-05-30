# frozen_string_literal: true

class ChangeAgentsIgnoreErrorsNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :agents, :ignore_errors, false
  end
end
