# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class LimitRulesToOneFile < ActiveRecord::Migration[7.1]
  def change
    drop_join_table :attacks, :rule_lists, comment: "Join table for attacks and rule lists."
    add_reference :attacks, :rule_list, comment: "The rule list used for the attack.", foreign_key: true
  end
end
