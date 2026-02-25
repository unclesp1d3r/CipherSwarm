# frozen_string_literal: true

# REASONING:
#   Why: The old unique index included `benchmark_date` (a mutable timestamp),
#     making it useless as a deduplication key — every submission with a new
#     timestamp bypassed the constraint. The natural key for a benchmark row
#     is `(agent_id, hash_type, device)`: one row per agent per hash-type per
#     device.
#   Alternatives Considered:
#     - Keep the old index and deduplicate in application code: fragile, still
#       allows duplicates from concurrent requests or direct SQL.
#     - Add a compound index without removing the old one: two conflicting
#       uniqueness constraints would confuse upsert_all.
#   Decision: Replace the old index with `(agent_id, hash_type, device) UNIQUE`
#     so that `upsert_all` can use it as a conflict target for idempotent writes.
class ChangeHashcatBenchmarksUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    remove_index :hashcat_benchmarks, name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be"

    # Remove duplicate rows sharing (agent_id, hash_type, device), keeping
    # only the row with the latest benchmark_date (ties broken by highest id).
    # This prevents the new unique index from failing in environments with
    # existing duplicates.
    execute <<~SQL.squish
      DELETE FROM hashcat_benchmarks
      WHERE id NOT IN (
        SELECT DISTINCT ON (agent_id, hash_type, device) id
        FROM hashcat_benchmarks
        ORDER BY agent_id, hash_type, device, benchmark_date DESC NULLS LAST, id DESC
      )
    SQL

    add_index :hashcat_benchmarks, %i[agent_id hash_type device], unique: true
  end

  def down
    remove_index :hashcat_benchmarks, %i[agent_id hash_type device]
    add_index :hashcat_benchmarks, %i[agent_id benchmark_date hash_type],
              name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be", unique: true
  end
end
