# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class LimitMaskListsToOneFile < ActiveRecord::Migration[7.1]
  def change
    drop_join_table :attacks, :mask_lists, comment: "Join table for attacks and mask lists."
    add_reference :attacks, :mask_list, comment: "The mask list used for the attack.", foreign_key: true
  end
end
