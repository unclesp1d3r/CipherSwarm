# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddStaleToTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :stale, :boolean, default: false, null: false, comment: "If new cracks since the last check, the task is stale and the new cracks need to be downloaded."
  end
end
