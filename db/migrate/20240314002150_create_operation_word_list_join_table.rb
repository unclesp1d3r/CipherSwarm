# frozen_string_literal: true

class CreateOperationWordListJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :operations, :word_lists do |t|
      t.index :operation_id
      t.index :word_list_id
    end
  end
end
