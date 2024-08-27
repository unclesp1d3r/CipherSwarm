# frozen_string_literal: true

class AddCascadeFromCampaignToProjects < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :campaigns, :projects
    add_foreign_key :campaigns, :projects, on_delete: :cascade
  end
end
