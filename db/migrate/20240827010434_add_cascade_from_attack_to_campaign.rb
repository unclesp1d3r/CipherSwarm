# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCascadeFromAttackToCampaign < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :attacks, :campaigns
    add_foreign_key :attacks, :campaigns, on_delete: :cascade
  end
end
