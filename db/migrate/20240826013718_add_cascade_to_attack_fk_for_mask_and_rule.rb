# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCascadeToAttackFkForMaskAndRule < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :attacks, :rule_lists
    add_foreign_key :attacks, :rule_lists, on_delete: :cascade

    remove_foreign_key :attacks, :mask_lists
    add_foreign_key :attacks, :mask_lists, on_delete: :cascade
  end
end
