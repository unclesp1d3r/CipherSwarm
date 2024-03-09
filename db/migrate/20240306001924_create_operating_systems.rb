class CreateOperatingSystems < ActiveRecord::Migration[7.1]
  def change
    create_table :operating_systems do |t|
      t.string :name, comment: "Name of the operating system"
      t.string :cracker_command, comment: "Command to run the cracker on this OS"

      t.timestamps
    end

    add_index :operating_systems, :name
  end
end
