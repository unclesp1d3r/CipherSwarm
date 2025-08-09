# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddPriorityEnumToCampaign < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :priority, :integer, default: 0, null: false,
                                                comment: ' -1: Deferred, 0: Routine, 1: Priority, 2: Urgent, 3: Immediate, 4: Flash, 5: Flash Override'
  end
end
