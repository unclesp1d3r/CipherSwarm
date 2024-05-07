# frozen_string_literal: true

class AddCounterCacheToHashList < ActiveRecord::Migration[7.1]
  def change
    add_column :hash_lists, :hash_items_count, :integer, default: 0
  end
end
