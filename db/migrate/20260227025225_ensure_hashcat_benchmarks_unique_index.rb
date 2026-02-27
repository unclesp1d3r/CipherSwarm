# frozen_string_literal: true

# REASONING:
#   Why: Environments where db:schema:load ran before migration 20260225025422
#     was added may still have the stale unique index on (agent_id,
#     benchmark_date, hash_type). This caused upsert_all to silently overwrite
#     benchmarks instead of accumulating them per (agent_id, hash_type, device).
#   Alternatives Considered:
#     - Making migration 20260225025422 itself idempotent: would change a
#       migration already applied in other environments, violating the
#       "never edit shipped migrations" principle.
#     - Using a rake task: not tracked by schema_migrations, so no guarantee
#       it runs in CI or production deploys.
#   Decision: A new idempotent migration that guards every operation with
#     index_exists? checks and deduplicates before adding the constraint.
#   Performance implications: The DISTINCT ON + DELETE is O(n) on the
#     hashcat_benchmarks table, which is small in practice.
class EnsureHashcatBenchmarksUniqueIndex < ActiveRecord::Migration[8.1]
  def up
    # Remove the old index if it still exists (some environments may have it
    # due to schema:load running before migration 20260225025422 was added).
    if index_exists?(:hashcat_benchmarks, name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be")
      remove_index :hashcat_benchmarks, name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be"
    end

    # Deduplicate rows before adding the correct unique index, keeping the
    # most recent benchmark for each (agent_id, hash_type, device) tuple.
    return if index_exists?(:hashcat_benchmarks, %i[agent_id hash_type device], unique: true)

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
    if index_exists?(:hashcat_benchmarks, %i[agent_id hash_type device], unique: true)
      remove_index :hashcat_benchmarks, %i[agent_id hash_type device]
    end

    return if index_exists?(:hashcat_benchmarks, name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be")

    add_index :hashcat_benchmarks, %i[agent_id benchmark_date hash_type],
              name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be", unique: true
  end
end
