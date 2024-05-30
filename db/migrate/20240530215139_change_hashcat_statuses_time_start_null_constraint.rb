# frozen_string_literal: true

class ChangeHashcatStatusesTimeStartNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_statuses, :time_start, false
  end
end
