class CreateCrackers < ActiveRecord::Migration[7.1]
  def change
    create_table :crackers do |t|
      t.string :name, comment: "Name of the cracker", index: { unique: true }
      t.timestamps
    end
  end
end