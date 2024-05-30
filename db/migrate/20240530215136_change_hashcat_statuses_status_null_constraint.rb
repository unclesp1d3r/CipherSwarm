# frozen_string_literal: true

class ChangeHashcatStatusesStatusNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_statuses, :status, false
  end
end
