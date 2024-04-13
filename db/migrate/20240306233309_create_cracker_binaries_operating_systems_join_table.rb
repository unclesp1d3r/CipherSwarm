# frozen_string_literal: true

class CreateCrackerBinariesOperatingSystemsJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :cracker_binaries, :operating_systems do |t|
      t.index :cracker_binary_id
      t.index :operating_system_id
    end
  end
end
