# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddStateToAgent < ActiveRecord::Migration[7.1]
  def change
    add_column :agents, :state, :string, default: "pending", null: false, comment: "The state of the agent"
    add_index :agents, :state
  end
end
