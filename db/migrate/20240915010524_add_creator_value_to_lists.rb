# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCreatorValueToLists < ActiveRecord::Migration[7.2]
  def change
    add_reference :word_lists, :creator, foreign_key: { to_table: :users }, comment: "The user who created this list"
    add_reference :rule_lists, :creator, foreign_key: { to_table: :users }, comment: "The user who created this list"
    add_reference :mask_lists, :creator, foreign_key: { to_table: :users }, comment: "The user who created this list"
  end
end
