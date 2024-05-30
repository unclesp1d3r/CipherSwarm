# frozen_string_literal: true

class ChangeAttacksCampaignIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :attacks, :campaign_id, false
  end
end
