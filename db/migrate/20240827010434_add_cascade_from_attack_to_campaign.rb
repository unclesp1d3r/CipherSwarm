# frozen_string_literal: true

class AddCascadeFromAttackToCampaign < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :attacks, :campaigns
    add_foreign_key :attacks, :campaigns, on_delete: :cascade
  end
end
