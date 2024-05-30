# frozen_string_literal: true

class ChangeOperatingSystemsCrackerCommandNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :operating_systems, :cracker_command, false
  end
end
