# frozen_string_literal: true

class AddQuarantineFieldsToCampaigns < ActiveRecord::Migration[8.1]
  def change
    change_table :campaigns, bulk: true do |t|
      t.boolean :quarantined, default: false, null: false
      t.text :quarantine_reason
    end
    add_index :campaigns, :quarantined, where: "quarantined = true", name: "index_campaigns_on_quarantined"
  end
end
