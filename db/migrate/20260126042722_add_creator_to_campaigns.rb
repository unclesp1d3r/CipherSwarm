# frozen_string_literal: true

class AddCreatorToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_reference :campaigns, :creator, foreign_key: { to_table: :users }, index: true, comment: "The user who created this campaign"
  end
end
