# frozen_string_literal: true

class AddAttacksCampaignIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :attacks, :campaign_id, name: :index_attacks_campaign_id
  end
end
