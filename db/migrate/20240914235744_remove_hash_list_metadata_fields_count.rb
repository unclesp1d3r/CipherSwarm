# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class RemoveHashListMetadataFieldsCount < ActiveRecord::Migration[7.2]
  def change
    remove_column :hash_lists, :metadata_fields_count, :integer
  end
end
