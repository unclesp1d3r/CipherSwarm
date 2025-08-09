# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class RemoveHashItemConstraint < ActiveRecord::Migration[7.1]
  def change
    remove_index :hash_items, column: %w[hash_value salt hash_list_id]
  end
end
