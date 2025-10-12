# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class HabtmAttacksMaskLists < ActiveRecord::Migration[7.1]
  def change
    create_table :attacks_mask_lists do |t|
      t.references :attack, null: false, foreign_key: true
      t.references :mask_list, null: false, foreign_key: true
      t.timestamps
    end
  end
end
