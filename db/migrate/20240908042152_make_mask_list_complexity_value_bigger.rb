# frozen_string_literal: true

class MakeMaskListComplexityValueBigger < ActiveRecord::Migration[7.2]
  def change
    change_column :mask_lists, :complexity_value, :numeric, limit: 32
  end
end
