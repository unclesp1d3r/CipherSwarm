# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class HabtmProjectsMaskLists < ActiveRecord::Migration[7.1]
  def change
    create_table :mask_lists_projects, id: false do |t|
      t.belongs_to :mask_list, index: true
      t.belongs_to :project, index: true
    end
  end
end
