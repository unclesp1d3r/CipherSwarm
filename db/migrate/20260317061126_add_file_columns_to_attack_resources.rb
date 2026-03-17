# frozen_string_literal: true

class AddFileColumnsToAttackResources < ActiveRecord::Migration[8.1]
  def change
    %i[word_lists rule_lists mask_lists].each do |table|
      add_column table, :file_path, :string
      add_column table, :file_size, :bigint
      add_column table, :file_name, :string
    end

    # Hash lists: temp file path for tus upload processing
    add_column :hash_lists, :temp_file_path, :string
  end
end
