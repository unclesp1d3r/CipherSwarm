# frozen_string_literal: true

class ChangeOperationToAttack < ActiveRecord::Migration[7.1]
  def change
    rename_table :operations, :attacks
  end
end
