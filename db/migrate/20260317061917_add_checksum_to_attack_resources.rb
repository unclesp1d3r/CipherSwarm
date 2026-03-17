# frozen_string_literal: true

class AddChecksumToAttackResources < ActiveRecord::Migration[8.1]
  def change
    %i[word_lists rule_lists mask_lists].each do |table|
      add_column table, :checksum, :string
    end
  end
end
