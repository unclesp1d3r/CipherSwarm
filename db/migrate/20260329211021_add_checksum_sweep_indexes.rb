# frozen_string_literal: true

# Adds partial indexes to support the RequeueUnverifiedResourcesJob sweep query:
#   WHERE checksum_verified = false AND updated_at < cutoff
# Without these, each 6-hour cron run performs full-table scans on all three
# resource tables. Partial indexes keep the index small (only unverified rows)
# and avoid impacting write performance on the majority of verified rows.
class AddChecksumSweepIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :word_lists, :updated_at,
              where: "checksum_verified = false",
              name: "index_word_lists_on_updated_at_checksum_unverified",
              algorithm: :concurrently

    add_index :rule_lists, :updated_at,
              where: "checksum_verified = false",
              name: "index_rule_lists_on_updated_at_checksum_unverified",
              algorithm: :concurrently

    add_index :mask_lists, :updated_at,
              where: "checksum_verified = false",
              name: "index_mask_lists_on_updated_at_checksum_unverified",
              algorithm: :concurrently
  end
end
