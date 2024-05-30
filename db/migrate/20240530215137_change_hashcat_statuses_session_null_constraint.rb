# frozen_string_literal: true

class ChangeHashcatStatusesSessionNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_statuses, :session, false
  end
end
