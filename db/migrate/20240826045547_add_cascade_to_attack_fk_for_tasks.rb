# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCascadeToAttackFkForTasks < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :tasks, :attacks
    add_foreign_key :tasks, :attacks, on_delete: :cascade
  end
end
