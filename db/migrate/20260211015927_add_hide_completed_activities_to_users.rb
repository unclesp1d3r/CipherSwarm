# frozen_string_literal: true

class AddHideCompletedActivitiesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :hide_completed_activities, :boolean, default: false, null: false
  end
end
