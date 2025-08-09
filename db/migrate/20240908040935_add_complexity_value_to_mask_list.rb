# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddComplexityValueToMaskList < ActiveRecord::Migration[7.2]
  def change
    add_column :mask_lists, :complexity_value, :bigint, default: 0, comment: "Total attemptable password values"
  end
end
