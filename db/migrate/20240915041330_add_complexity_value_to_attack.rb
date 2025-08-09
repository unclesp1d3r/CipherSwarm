# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddComplexityValueToAttack < ActiveRecord::Migration[7.2]
  def change
    add_column :attacks, :complexity_value, :numeric, default: 0, null: false, comment: 'Complexity value of the attack'
    add_index :attacks, :complexity_value
  end
end
