# frozen_string_literal: true

class AddPriorityEnumToCampaign < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :priority, :integer, default: 0, null: false,
                                                comment: ' -1: Defered, 0: Routine, 1: Priority, 2: Urgent, 3: Immediate, 4: Flash, 5: Flash Override'
  end
end
