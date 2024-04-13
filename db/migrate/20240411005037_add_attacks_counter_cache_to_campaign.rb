# frozen_string_literal: true

class AddAttacksCounterCacheToCampaign < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :attacks_count, :integer, default: 0, null: false
  end
end
