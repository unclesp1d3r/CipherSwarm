# frozen_string_literal: true

class AddRoleToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :role, :integer, default: 0,
                                        comment: 'The role of the user, either basic or admin'
  end
end
