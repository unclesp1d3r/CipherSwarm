# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCascadeToAttackFk < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :attacks, :word_lists
    add_foreign_key :attacks, :word_lists, on_delete: :cascade
  end
end
