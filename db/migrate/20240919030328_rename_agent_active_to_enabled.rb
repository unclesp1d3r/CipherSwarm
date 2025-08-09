# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class RenameAgentActiveToEnabled < ActiveRecord::Migration[7.2]
  def change
    rename_column :agents, :active, :enabled
  end
end
