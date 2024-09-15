# frozen_string_literal: true

class AddComplexityValueToMaskList < ActiveRecord::Migration[7.2]
  def change
    add_column :mask_lists, :complexity_value, :bigint, default: 0, comment: "Total attemptable password values"
  end
end
