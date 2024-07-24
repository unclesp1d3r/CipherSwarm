# frozen_string_literal: true

class ChangeLineCountToBigIntInWordList < ActiveRecord::Migration[7.1]
  def change
    change_column :word_lists, :line_count, :bigint
  end
end
