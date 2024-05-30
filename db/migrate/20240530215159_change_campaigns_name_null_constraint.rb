# frozen_string_literal: true

class ChangeCampaignsNameNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :campaigns, :name, false
  end
end
