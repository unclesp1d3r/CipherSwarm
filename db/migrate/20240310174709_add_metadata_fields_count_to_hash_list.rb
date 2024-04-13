# frozen_string_literal: true

class AddMetadataFieldsCountToHashList < ActiveRecord::Migration[7.1]
  def change
    add_column :hash_lists, :metadata_fields_count, :integer, default: 0, null: false,
                                                              comment: "Number of metadata fields in the hash list file. Default is 0."
  end
end
