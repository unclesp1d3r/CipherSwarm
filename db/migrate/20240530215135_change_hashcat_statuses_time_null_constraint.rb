# frozen_string_literal: true

class ChangeHashcatStatusesTimeNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_statuses, :time, false
  end
end
