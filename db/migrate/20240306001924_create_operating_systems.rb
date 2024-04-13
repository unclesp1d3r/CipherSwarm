# frozen_string_literal: true

class CreateOperatingSystems < ActiveRecord::Migration[7.1]
  def change
    create_table :operating_systems do |t|
      t.string :name, comment: "Name of the operating system", index: { unique: true }
      t.string :cracker_command, comment: "Command to run the cracker on this OS"

      t.timestamps
    end
  end
end
