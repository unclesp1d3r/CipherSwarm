class AddProjectToCampaign < ActiveRecord::Migration[7.1]
  def change
    add_reference :campaigns, :project, null: false, foreign_key: true
  end
end
