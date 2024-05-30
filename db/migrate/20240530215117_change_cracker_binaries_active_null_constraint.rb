# frozen_string_literal: true

class ChangeCrackerBinariesActiveNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cracker_binaries, :active, false
  end
end
