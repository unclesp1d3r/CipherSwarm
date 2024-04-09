# frozen_string_literal: true

class AddTimestampsToOperations < ActiveRecord::Migration[7.1]
  def change
    add_timestamps :operations, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end
end
