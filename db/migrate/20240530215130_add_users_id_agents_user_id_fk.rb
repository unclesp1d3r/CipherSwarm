# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddUsersIdAgentsUserIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :agents, :users, column: :user_id, primary_key: :id
  end
end
