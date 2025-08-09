# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class RemovePositioningFromAttack < ActiveRecord::Migration[7.1]
  def change
    remove_index :attacks, name: "index_attacks_on_campaign_id_and_position"
    remove_column :attacks, :position, :integer
  end
end
