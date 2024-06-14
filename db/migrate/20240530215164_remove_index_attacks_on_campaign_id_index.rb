# frozen_string_literal: true

class RemoveIndexAttacksOnCampaignIdIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index nil, name: "index_attacks_on_campaign_id"
  end
end
