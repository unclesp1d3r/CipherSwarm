# frozen_string_literal: true

class AddCampaignToAttack < ActiveRecord::Migration[7.1]
  def change
    add_reference :operations, :campaign, null: true, foreign_key: true
  end
end
