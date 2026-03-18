# frozen_string_literal: true

class AddChecksumVerifiedToAttackResources < ActiveRecord::Migration[8.1]
  def change
    add_column :word_lists, :checksum_verified, :boolean, default: true, null: false
    add_column :rule_lists, :checksum_verified, :boolean, default: true, null: false
    add_column :mask_lists, :checksum_verified, :boolean, default: true, null: false
  end
end
