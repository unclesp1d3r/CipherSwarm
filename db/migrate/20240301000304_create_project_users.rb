class CreateProjectUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :project_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.integer :role, default: 0, null: false

      t.timestamps
    end
  end
end
