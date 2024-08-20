# frozen_string_literal: true

class AddDeletedAtToAttacks < ActiveRecord::Migration[7.1]
  def change
    add_column :attacks, :deleted_at, :datetime
    add_index :attacks, :deleted_at
  end
end
