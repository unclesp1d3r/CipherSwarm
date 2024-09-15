# frozen_string_literal: true

class RemoveHashListMetadataFieldsCount < ActiveRecord::Migration[7.2]
  def change
    remove_column :hash_lists, :metadata_fields_count, :integer
  end
end
