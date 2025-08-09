# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class LimitWordListsToOneFile < ActiveRecord::Migration[7.1]
  def change
    drop_join_table :attacks, :word_lists, comment: "Join table for attacks and word lists."
    add_reference :attacks, :word_list, comment: "The word list used for the attack.", foreign_key: true
  end
end
