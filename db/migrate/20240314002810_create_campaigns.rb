# frozen_string_literal: true

class CreateCampaigns < ActiveRecord::Migration[7.1]
  def change
    create_table :campaigns do |t|
      t.string :name
      t.references :hash_list, null: false, foreign_key: true

      t.timestamps
    end
  end
end
