# frozen_string_literal: true

class AddKeyspaceLimitsToTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :keyspace_limit, :integer, default: 0,
                                                  comment: "The maximum number of keyspace values to process."
    add_column :tasks, :keyspace_offset, :integer, default: 0, comment: "The starting keyspace offset."
  end
end
