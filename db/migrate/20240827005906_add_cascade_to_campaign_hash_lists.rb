# frozen_string_literal: true

class AddCascadeToCampaignHashLists < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :campaigns, :hash_lists
    add_foreign_key :campaigns, :hash_lists, on_delete: :cascade
  end
end
