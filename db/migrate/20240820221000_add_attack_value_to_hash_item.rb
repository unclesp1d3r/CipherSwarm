# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddAttackValueToHashItem < ActiveRecord::Migration[7.1]
  def change
    add_reference :hash_items, :attack, null: true, foreign_key: true, comment: "The attack that cracked this hash"
  end
end
