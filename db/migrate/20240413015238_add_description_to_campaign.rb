# frozen_string_literal: true

class AddDescriptionToCampaign < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :description, :text
  end
end
