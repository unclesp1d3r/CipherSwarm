# frozen_string_literal: true

class ChangeRuleListsSensitiveNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :rule_lists, :sensitive, false
  end
end
