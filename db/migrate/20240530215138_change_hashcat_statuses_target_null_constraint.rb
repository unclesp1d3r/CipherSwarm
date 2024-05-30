# frozen_string_literal: true

class ChangeHashcatStatusesTargetNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_statuses, :target, false
  end
end
