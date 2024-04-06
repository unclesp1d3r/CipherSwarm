# frozen_string_literal: true

class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false, limit: 100, index: { unique: true }, comment: 'Name of the project'
      t.text :description, limit: 512, comment: 'Description of the project'

      t.timestamps
    end
  end
end
