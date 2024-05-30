# frozen_string_literal: true

class ChangeOperatingSystemsNameNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :operating_systems, :name, false
  end
end
