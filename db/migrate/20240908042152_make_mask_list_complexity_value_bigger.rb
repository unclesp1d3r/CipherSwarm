# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class MakeMaskListComplexityValueBigger < ActiveRecord::Migration[7.2]
  def change
    change_column :mask_lists, :complexity_value, :numeric, limit: 32
  end
end
