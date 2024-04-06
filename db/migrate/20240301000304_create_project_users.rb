# frozen_string_literal: true

class CreateProjectUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :project_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.integer :role, default: 0, null: false, comment: 'The role of the user in the project.'

      t.timestamps
    end
  end
end
