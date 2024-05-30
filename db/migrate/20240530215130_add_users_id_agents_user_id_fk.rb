# frozen_string_literal: true

class AddUsersIdAgentsUserIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :agents, :users, column: :user_id, primary_key: :id
  end
end
