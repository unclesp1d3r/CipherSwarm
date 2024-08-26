# frozen_string_literal: true

class AddDeletedAtToCampaigns < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :deleted_at, :datetime
    add_index :campaigns, :deleted_at
  end
end
