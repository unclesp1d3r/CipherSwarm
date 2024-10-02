# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCascadeToCampaignHashLists < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :campaigns, :hash_lists
    add_foreign_key :campaigns, :hash_lists, on_delete: :cascade
  end
end
