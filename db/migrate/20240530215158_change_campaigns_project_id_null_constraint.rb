# frozen_string_literal: true

class ChangeCampaignsProjectIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :campaigns, :project_id, false
  end
end
