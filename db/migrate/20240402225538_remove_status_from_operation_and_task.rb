# frozen_string_literal: true

class RemoveStatusFromOperationAndTask < ActiveRecord::Migration[7.1]
  def change
    remove_column :operations, :status, :integer
    remove_column :tasks, :status, :integer
  end
end
