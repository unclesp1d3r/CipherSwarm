# frozen_string_literal: true

class ChangeRuleListsProcessedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :rule_lists, :processed, false
  end
end
