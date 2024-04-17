# frozen_string_literal: true

class AddStartAndEndTimeToAttack < ActiveRecord::Migration[7.1]
  def change
    add_column :attacks, :start_time, :datetime, null: true, comment: "The time the attack started."
    add_column :attacks, :end_time, :datetime, null: true, comment: "The time the attack ended."
  end
end
