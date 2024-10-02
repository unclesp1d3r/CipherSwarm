# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class ChangeHashItemsCrackedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hash_items, :cracked, false
  end
end
