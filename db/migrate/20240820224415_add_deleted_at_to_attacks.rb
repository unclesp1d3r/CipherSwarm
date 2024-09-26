# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddDeletedAtToAttacks < ActiveRecord::Migration[7.1]
  def change
    add_column :attacks, :deleted_at, :datetime
    add_index :attacks, :deleted_at
  end
end
