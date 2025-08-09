# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class RemoveUnusedAgentParameters < ActiveRecord::Migration[7.1]
  def change
    change_table :agents, bulk: true do |t|
      t.remove :command_parameters, :text
      t.remove :cpu_only, :boolean, default: false, null: false
      t.remove :ignore_errors, :boolean, default: false, null: false
      t.remove :trusted, :boolean, default: false, null: false
    end
  end
end
